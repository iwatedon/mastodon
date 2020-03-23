module StoplightAdminRails
  class HomeController < ApplicationController
    layout 'stoplight_admin_rails/application'

    def index
      @lights = lights
      @stats  = stat_params(@lights)
      respond_to do |format|
        format.html { render :index }
      end
    end

    def stats
      @lights = lights
      @stats  = stat_params(@lights)
      respond_to do |format|
        format.json { render :json => { stats: @stats, lights: @lights }  }
      end
    end

    def do_lock
      with_lights { |l| lock(l) }
      redirect_to root_path
    end

    def do_unlock
      with_lights { |l| unlock(l) }
      redirect_to root_path
    end

    def make_green
      with_lights { |l| green(l) }
      redirect_to root_path
    end

    def make_red
      with_lights { |l| red(l) }
      redirect_to root_path
    end

    def make_green_all
      data_store.names
        .reject { |l| Stoplight::Light.new(l) {}.color == Stoplight::Color::GREEN }
        .each { |l| green(l) }
      redirect_to root_path
    end

    private
    COLORS = [
      GREEN = Stoplight::Color::GREEN,
      YELLOW = Stoplight::Color::YELLOW,
      RED = Stoplight::Color::RED
    ].freeze
    
    def data_store
      return @data_store if defined?(@data_store)
      redis = Redis.new
      data_store = Stoplight::DataStore::Redis.new(redis)
      @data_store = Stoplight::Light.default_data_store = data_store
    end

    def lights
      data_store
        .names
        .map { |name| light_info(name) }
        .sort_by { |light| light_sort_key(light) }
    end

    def light_info(light)
      l = Stoplight::Light.new(light) {}
      color = l.color
      failures, state = l.data_store.get_all(l)

      {
        name: light,
        color: color,
        failures: failures,
        locked: locked?(state)
      }
    end

    def light_sort_key(light)
      [-COLORS.index(light[:color]),
       light[:name]]
    end

    def locked?(state)
      [Stoplight::State::LOCKED_GREEN,
       Stoplight::State::LOCKED_RED]
        .include?(state)
    end

    def stat_params(ls)
      h = {
        count_red: 0, count_yellow: 0, count_green: 0,
        percent_red: 0, percent_yellow: 0, percent_green: 0
      }
      return h if (size = ls.size).zero?

      h[:count_red] = ls.count { |l| l[:color] == RED }
      h[:count_yellow] = ls.count { |l| l[:color] == YELLOW }
      h[:count_green] = size - h[:count_red] - h[:count_yellow]

      h[:percent_red] = (100.0 * h[:count_red] / size).ceil
      h[:percent_yellow] = (100.0 * h[:count_yellow] / size).ceil
      h[:percent_green] = 100.0 - h[:percent_red] - h[:percent_yellow]

      h
    end

    def lock(light)
      l = Stoplight::Light.new(light) {}
      new_state =
        case l.color
        when Stoplight::Color::GREEN
          Stoplight::State::LOCKED_GREEN
        else
          Stoplight::State::LOCKED_RED
        end

      data_store.set_state(l, new_state)
    end

    def unlock(light)
      l = Stoplight::Light.new(light) {}
      data_store.set_state(l, Stoplight::State::UNLOCKED)
    end

    def green(light)
      l = Stoplight::Light.new(light) {}
      if data_store.get_state(l) == Stoplight::State::LOCKED_RED
        new_state = Stoplight::State::LOCKED_GREEN
        data_store.set_state(l, new_state)
      end

      data_store.clear_failures(l)
    end

    def red(light)
      l = Stoplight::Light.new(light) {}
      data_store.set_state(l, Stoplight::State::LOCKED_RED)
    end

    def with_lights
      [*params[:names]]
        .map  { |l| URI.unescape(l) }
        .each { |l| yield(l) }
    end
  end
end
