require 'date'
require 'fileutils'

class Game
  attr_reader :date, :time

  def initialize(date,time)
    @date = date
    @time = time
  end

  def day_name
    days = { 1 => 'Пн', 2 => 'Вт', 3 => 'Ср', 4 => 'Чт', 5 => 'Пт', 6 => 'Сб', 0 => 'Вс' }
    days[@date.wday]
  end

  def formatted_date
    @date.strftime('%d.%m.%Y')
  end

end

class Team
  attr_reader :name,:city

  def initialize(name,city)
    @name = name
    @city = city
  end

  def name
    "#{@name}"
  end

  def city
    "#{@city}"
  end
end

class Match
  attr_reader :team1, :team2, :city

  def initialize(team1, team2)
    @team1 = team1
    @team2 = team2
    @city = team1.city
  end

  def to_s
    "#{@team1.name} vs #{@team2.name}"
  end
end

class CalendarBuilder
  VALID_TIMES = ['12:00', '15:00', '18:00']
  MAX_GAMES_PER_SLOT = 2

  def initialize(args)
    @teams_file = args[0]
    @start_date = parse_date(args[1])
    @end_date = parse_date(args[2])
    @output_file = args[3]
  end

  def build
    teams = load_teams

    matches = generate_matches(teams)
    slots = generate_available_slots

    schedule = distribute_matches(matches, slots)
    write_calendar(schedule)

    puts "Календарь создан: #{@output_file}"
  end

  def distribute_matches(matches, slots)
    schedule = {}
    
    total_slots = slots.count
    total_matches = matches.count
    
    step = total_slots.to_f / total_matches
    current_index = 0.0

    matches.each do |match|
      slot_index = current_index.floor
      slot_index = total_slots - 1 if slot_index >= total_slots
      
      slot = slots[slot_index]
      
      schedule[slot.date] ||= []
      schedule[slot.date] << { time: slot.time, match: match }
      
      current_index += step
    end

    schedule.each do |date, games|
      games.sort_by! { |g| g[:time] }
    end

    schedule
  end

  def load_teams
    teams = []
    File.foreach(@teams_file, encoding: 'UTF-8') do |line|
      line = line.strip

      parts = line.split('—')
      if parts.count < 2
        raise StandardError, "Неверный формат строки в файле команд: '#{line}'"
      end
      
      name = parts[0][3..-1].strip
      city = parts[1].strip

      teams << Team.new(name, city)
    end
    teams
  end

  def generate_matches(teams)
    teams.permutation(2).map { |t1, t2| Match.new(t1, t2) }.shuffle
  end

  def parse_date(str)
    begin
      Date.strptime(str, '%d.%m.%Y')
    rescue ArgumentError
      raise ArgumentError, "Неверный формат даты: #{str}"
    end
  end

  def generate_available_slots
    slots = []
    @start_date.upto(@end_date) do |date|
      next unless [5, 6, 0].include?(date.wday)

      VALID_TIMES.each do |time|
        MAX_GAMES_PER_SLOT.times do
          slots << Game.new(date, time)
        end
      end
    end
    slots
  end

  def write_calendar(schedule)
    File.open(@output_file, 'w', encoding: 'UTF-8') do |f|
      f.puts "СПОРТИВНЫЙ КАЛЕНДАРЬ"
      f.puts "=" * 60
      f.puts "Период: #{@start_date.strftime('%d.%m.%Y')} - #{@end_date.strftime('%d.%m.%Y')}"
      f.puts "=" * 60
      f.puts ""

      schedule.each do |date, games|
        slot_obj = Game.new(date, '00:00')
        f.puts "#{slot_obj.formatted_date} (#{slot_obj.day_name})"
        
        games.each do |game|
          match = game[:match]
          f.puts "#{game[:time]} | #{game[:match].team1.name} против #{match.team2.name} (#{match.team2.city})"
        end
        f.puts ""
      end
      
      f.puts "=" * 60
      f.puts "Всего игр: #{schedule.values.flatten.count}"
    end
  end
end

begin
  builder = CalendarBuilder.new(ARGV)
  builder.build
end
