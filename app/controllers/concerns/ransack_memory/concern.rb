module RansackMemory
  module Concern
    extend ActiveSupport::Concern

    def save_and_load_filters
      return if params[::RansackMemory::Core.config[:param]].is_a? String

      if ::RansackMemory::Core.config[:storage_klass]
        session_storage = ::RansackMemory::Core.config[:storage_klass].constantize.new(self)
      else
        session_storage = session
      end

      user_set_key_identifier = respond_to?(:set_session_key_identifier) ? send(:set_session_key_identifier) : nil

      session_key_identifier = ::RansackMemory::Core.config[:session_key_format]
                                   .gsub('%controller_name%', controller_name)
                                   .gsub('%action_name%', action_name)
                                   .gsub('%request_format%', request.format.symbol.to_s)

      session_key_base = user_set_key_identifier.presence || "ranmemory_#{session_key_identifier}"
      session_key_base = "ranmemory_#{session_key_base}" unless session_key_base.starts_with?('ranmemory')

      # permit search params
      params[::RansackMemory::Core.config[:param]].permit! if params[::RansackMemory::Core.config[:param]].present? && params[::RansackMemory::Core.config[:param]].respond_to?(:permit)

      # cancel filter if button pressed
      if params[:cancel_filter] == "true"
        session_storage["#{session_key_base}"] = nil
        session_storage["#{session_key_base}_page"] = nil
        session_storage["#{session_key_base}_per_page"] = nil
      end

      # search term saving
      session_storage["#{session_key_base}"] = params[::RansackMemory::Core.config[:param]].to_h if params[::RansackMemory::Core.config[:param]].present?

      # page number saving
      target_page = params[:page].presence || 1
      session_storage["#{session_key_base}_page"] = target_page

      # per page saving
      session_storage["#{session_key_base}_per_page"] = params[:per_page] if params[:per_page].present?

      # search term load
      params[::RansackMemory::Core.config[:param]] = session_storage["#{session_key_base}"] if session_storage["#{session_key_base}"].present?

      # page number load
      params[:page] = session_storage["#{session_key_base}_page"].presence

      # per page load
      params[:per_page] = session_storage["#{session_key_base}_per_page"].presence

      # set page number to 1 if filter has changed
      if (params[::RansackMemory::Core.config[:param]].present? && session_storage[:last_q_params] != params[::RansackMemory::Core.config[:param]].permit!.to_h) || (params[:cancel_filter].present? && session_storage["#{session_key_base}_page"] != params[:page])
        params[:page] = nil
        session_storage["#{session_key_base}_page"] = nil
      end

      session_storage[:last_q_params] = params[::RansackMemory::Core.config[:param]]&.to_unsafe_h

      # session[:last_page] = params[:page]
    end

    # controller method, useful when you want to clear sessions when sign into another user
    def clear_sessions
      session_storage.keys.each do |key|
        session_storage.delete(key) if key =~ /ranmemory_/
      end
    end
  end
end
