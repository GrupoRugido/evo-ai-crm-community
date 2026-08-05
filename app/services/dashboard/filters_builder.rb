# frozen_string_literal: true

module Dashboard
  class FiltersBuilder
    DEFAULT_RANGE_DAYS = 30

    # EVO-CUSTOM: valor impossivel usado quando o usuario nao tem caixa nenhuma.
    # Sem a sentinela, um array vazio faria `inbox_id.present?` ser falso e o
    # filtro NAO seria aplicado — cliente sem caixa veria as metricas de todos.
    NO_ACCESS_SENTINEL = '00000000-0000-0000-0000-000000000000'

    attr_reader :params

    # EVO-CUSTOM: allowed_inbox_ids nil = sem restricao (admin/service);
    # array = o usuario so pode enxergar essas caixas. Todos os escopos deste
    # builder passam pelo metodo privado inbox_id, entao restringir aqui cobre
    # conversas, mensagens, eventos, pipeline e CSAT de uma vez.
    def initialize(account: nil, params:, allowed_inbox_ids: nil)
      @params = params
      @allowed_inbox_ids = allowed_inbox_ids.nil? ? nil : (allowed_inbox_ids.presence || [NO_ACCESS_SENTINEL])
    end

    def time_range
      @time_range ||= begin
        parsed_since = parse_datetime(params[:since])
        parsed_until = parse_datetime(params[:until])

        if parsed_since.present? || parsed_until.present?
          since_time = (parsed_since || DEFAULT_RANGE_DAYS.days.ago).beginning_of_day
          until_time = (parsed_until || Time.current).end_of_day
          if since_time > until_time
            since_time, until_time = until_time.beginning_of_day, since_time.end_of_day
          end
          since_time..until_time
        else
          DEFAULT_RANGE_DAYS.days.ago.beginning_of_day..Time.current.end_of_day
        end
      end
    end

    def applied_filters
      {
        pipeline_id: pipeline_id,
        team_id: team_id,
        inbox_id: inbox_id,
        user_id: user_id,
        since: time_range.begin.to_i,
        until: time_range.end.to_i
      }.compact
    end

    def conversation_scope(base_scope = nil, apply_time_range: true)
      scope = (base_scope || Conversation.all)
      scope = scope.where(created_at: time_range) if apply_time_range
      scope = scope.where(team_id: team_id) if team_id.present?
      scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
      scope = scope.where(assignee_id: user_id) if user_id.present?
      scope = scope.joins(:pipeline_items).where(pipeline_items: { pipeline_id: pipeline_id }).distinct if pipeline_id.present?
      scope
    end

    def reporting_events_scope(base_scope = nil)
      scope = (base_scope || ReportingEvent.all).where(created_at: time_range)
      scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
      scope = scope.where(user_id: user_id) if user_id.present?
      scope = scope.joins(:conversation).where(conversations: { team_id: team_id }) if team_id.present?

      if pipeline_id.present?
        scope = scope.joins(conversation: :pipeline_items).where(pipeline_items: { pipeline_id: pipeline_id })
      end

      scope.distinct
    end

    def pipeline_items_scope(base_scope = nil)
      scope = (base_scope || PipelineItem.all).where(created_at: time_range)
      scope = scope.where(pipeline_id: pipeline_id) if pipeline_id.present?

      if team_id.present? || inbox_id.present? || user_id.present?
        scope = scope.joins(:conversation)
        scope = scope.where(conversations: { team_id: team_id }) if team_id.present?
        scope = scope.where(conversations: { inbox_id: inbox_id }) if inbox_id.present?
        scope = scope.where(conversations: { assignee_id: user_id }) if user_id.present?
      end

      scope
    end

    def pipeline_tasks_scope(base_scope = nil)
      scope = (base_scope || PipelineTask.all).where(created_at: time_range)
      scope = scope.joins(:pipeline_item)
      scope = scope.where(pipeline_items: { pipeline_id: pipeline_id }) if pipeline_id.present?

      if team_id.present? || inbox_id.present? || user_id.present?
        scope = scope.joins(pipeline_item: :conversation)
        scope = scope.where(conversations: { team_id: team_id }) if team_id.present?
        scope = scope.where(conversations: { inbox_id: inbox_id }) if inbox_id.present?
        scope = scope.where(conversations: { assignee_id: user_id }) if user_id.present?
      end

      scope
    end

    def messages_scope(base_scope = nil)
      scope = (base_scope || Message.all).where(created_at: time_range)
      scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
      joins_applied = false

      if team_id.present? || pipeline_id.present? || user_id.present?
        scope = scope.joins(:conversation)
        joins_applied = true
        scope = scope.where(conversations: { team_id: team_id }) if team_id.present?
        scope = scope.where(conversations: { assignee_id: user_id }) if user_id.present?
      end

      if pipeline_id.present?
        scope = scope.joins(conversation: :pipeline_items).where(pipeline_items: { pipeline_id: pipeline_id })
        joins_applied = true
      end

      return scope unless joins_applied

      # Avoid DISTINCT messages.* on json/jsonb columns (PostgreSQL has no equality operator for json)
      deduped_ids = scope.unscope(:select, :order).reselect(:id).distinct
      (base_scope || Message.all).where(id: deduped_ids)
    end

    def csat_scope(base_scope = nil)
      scope = (base_scope || CsatSurveyResponse.all).where(created_at: time_range)
      scope = scope.where(assigned_agent_id: user_id) if user_id.present?
      joins_applied = false

      if team_id.present? || inbox_id.present? || pipeline_id.present?
        scope = scope.joins(:conversation)
        joins_applied = true
        scope = scope.where(conversations: { team_id: team_id }) if team_id.present?
        scope = scope.where(conversations: { inbox_id: inbox_id }) if inbox_id.present?
      end

      if pipeline_id.present?
        scope = scope.joins(conversation: :pipeline_items).where(pipeline_items: { pipeline_id: pipeline_id })
        joins_applied = true
      end

      return scope unless joins_applied

      deduped_ids = scope.unscope(:select, :order).reselect(:id).distinct
      (base_scope || CsatSurveyResponse.all).where(id: deduped_ids)
    end

    private

    def pipeline_id
      params[:pipeline_id].presence
    end

    def team_id
      params[:team_id].presence
    end

    # EVO-CUSTOM: intersecao entre o filtro pedido e as caixas permitidas.
    # Pedir uma caixa fora do escopo nao vira erro: cai no proprio escopo
    # (o cliente nunca ve mais do que as caixas dele).
    def inbox_id
      requested = params[:inbox_id].presence
      return requested if @allowed_inbox_ids.nil?
      return @allowed_inbox_ids if requested.blank?

      @allowed_inbox_ids.map(&:to_s).include?(requested.to_s) ? requested : @allowed_inbox_ids
    end

    def user_id
      params[:user_id].presence
    end

    def parse_datetime(value)
      return if value.blank?

      if value.to_s.match?(/\A\d+\z/)
        Time.zone.at(value.to_i)
      else
        Time.zone.parse(value.to_s)
      end
    rescue ArgumentError, TypeError
      nil
    end
  end
end
