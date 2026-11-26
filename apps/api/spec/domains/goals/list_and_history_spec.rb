require "rails_helper"

RSpec.describe "Goals: today list and history" do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.utc(2026, 11, 17, 15, 0) }
  let(:today) { Date.new(2026, 11, 17) }
  let(:yesterday) { today - 1 }

  def new_user = Identity::User.create!(email: "h-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id

  let(:user_id) { new_user }

  before do
    travel_to(now)
    allow(UserProfile::Api).to receive(:time_zone).and_return("America/Sao_Paulo")
  end

  def create_goal(type, owner: user_id) = Goals::Api.create_goal(user_id: owner, goal_type: type)

  # Writes check-ins directly: the history reads what is stored, whatever the window of the API.
  def record(goal, date, source = "manual", owner: user_id)
    Goals::GoalCheckIn.create!(goal_id: goal.id, user_id: owner, local_date: date, source:, checked_at: Time.current,
                               source_ref: (SecureRandom.uuid if source == "food_entry"))
  end

  def history(**args) = Goals::Api.history(user_id:, **args)

  it "lists active then paused goals with done_today and done_yesterday" do
    paused = create_goal("sleep_routine")
    travel(1.minute)
    first = create_goal("drink_water")
    travel(1.minute)
    second = create_goal("log_meals")
    Goals::Api.change_status(user_id:, goal_id: paused.id, status: "paused")
    record(first, today)
    record(second, yesterday)

    list = Goals::Api.list_goals(user_id:)

    expect(list).to have_attributes(today_local_date: today, yesterday_local_date: yesterday)
    expect(list.goals.map { |g| [ g.goal_type, g.status, g.done_today, g.done_yesterday ] }).to eq(
      [ [ "drink_water", "active", true, false ], [ "log_meals", "active", false, true ], [ "sleep_routine", "paused", false, false ] ]
    )
  end

  it "a paused goal keeps its recorded days" do
    goal = create_goal("drink_water")
    record(goal, today)
    Goals::Api.change_status(user_id:, goal_id: goal.id, status: "paused")

    info = Goals::Api.list_goals(user_id:).goals.sole

    expect(info).to have_attributes(status: "paused", done_today: true)
    expect(history.days.map(&:local_date)).to eq([ today ])
  end

  it "ended goals are not in the list but are in the history" do
    goal = create_goal("drink_water")
    record(goal, today)
    Goals::Api.change_status(user_id:, goal_id: goal.id, status: "ended")

    expect(Goals::Api.list_goals(user_id:).goals).to be_empty
    expect(history.days.map { |d| [ d.goal_id, d.goal_status ] }).to eq([ [ goal.id, "ended" ] ])
  end

  it "history has only completed days, newest first, with their sources" do
    water = create_goal("drink_water")
    meals = create_goal("log_meals")
    record(water, today)
    record(water, today - 3)
    record(meals, today, "manual")
    record(meals, today, "food_entry")
    record(meals, today, "food_entry")
    record(meals, today - 1, "food_entry")

    page = history

    expect(page).to be_ok
    expect(page.next_cursor).to be_nil
    by_goal_desc = [ [ water, [ "manual" ] ], [ meals, [ "food_entry", "manual" ] ] ].sort_by { |goal, _| goal.id }.reverse
    expect(page.days.map { |d| [ d.local_date, d.goal_id, d.goal_status, d.sources ] }).to eq(
      by_goal_desc.map { |goal, sources| [ today, goal.id, "active", sources ] } +
      [ [ today - 1, meals.id, "active", [ "food_entry" ] ], [ today - 3, water.id, "active", [ "manual" ] ] ]
    )
  end

  it "history is paginated by cursor without gaps or repeats" do
    goal = create_goal("drink_water")
    other = create_goal("log_meals")
    (0...45).each { |n| record(goal, today - n) }
    (0...5).each { |n| record(other, today - n) }

    pages = []
    cursor = nil
    loop do
      page = history(cursor:, limit: 20)
      pages << page
      cursor = page.next_cursor
      break unless cursor
    end

    keys = pages.flat_map(&:days).map { |d| [ d.local_date, d.goal_id ] }
    expect(pages.map { |p| p.days.size }).to eq([ 20, 20, 10 ])
    expect(keys.size).to eq(50)
    expect(keys.uniq).to eq(keys)
    expect(keys).to eq(keys.sort_by { |date, id| [ date, id ] }.reverse)
  end

  it "history filters by goal" do
    water = create_goal("drink_water")
    meals = create_goal("log_meals")
    record(water, today)
    record(meals, today)

    expect(history(goal_id: meals.id).days.map(&:goal_id)).to eq([ meals.id ])
  end

  it "history is isolated per person" do
    mine = create_goal("drink_water")
    record(mine, today)
    other_id = new_user
    theirs = create_goal("drink_water", owner: other_id)
    record(theirs, today, owner: other_id)
    record(theirs, today - 1, owner: other_id)

    expect(history.days.map(&:goal_id)).to eq([ mine.id ])
    expect(Goals::Api.history(user_id: other_id).days.map { |d| [ d.goal_id, d.local_date ] }).to eq([ [ theirs.id, today ], [ theirs.id, today - 1 ] ])
    expect(history(goal_id: theirs.id)).to eq(:not_found)
    expect(history(goal_id: "not-a-uuid")).to eq(:not_found)
    expect(Goals::Api.list_goals(user_id: other_id).goals.map(&:id)).to eq([ theirs.id ])
  end

  it "limit 0, 101 and a bad cursor are validation errors" do
    [ [ { limit: 0 }, "limit", "out_of_range" ], [ { limit: 101 }, "limit", "out_of_range" ], [ { limit: "abc" }, "limit", "out_of_range" ],
      [ { cursor: "garbage" }, "cursor", "invalid" ], [ { cursor: Base64.urlsafe_encode64([ "x", "y" ].to_json) }, "cursor", "invalid" ] ].each do |args, field, code|
      result = history(**args)

      expect(result).not_to be_ok
      expect(result).to have_attributes(code: "validation_failed", details: [ { field:, code: } ])
    end
    expect(history(limit: 100)).to be_ok
  end

  it "history query count is the same for 10 and 30 days" do
    goal = create_goal("drink_water")
    count_queries = lambda do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
      end
      page = history(limit: 100)
      ActiveSupport::Notifications.unsubscribe(subscriber)
      [ queries, page.days.size ]
    end
    history # warm up

    (0...10).each { |n| record(goal, today - n) }
    few, few_days = count_queries.call
    (10...30).each { |n| record(goal, today - n) }
    many, many_days = count_queries.call

    expect([ few_days, many_days ]).to eq([ 10, 30 ])
    expect(many.size).to eq(few.size), "#{few.size} queries for 10 days, #{many.size} for 30:\n#{many.join("\n")}"
  end
end
