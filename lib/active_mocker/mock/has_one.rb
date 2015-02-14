module ActiveMocker
  module Mock

    class HasOne < SingleRelation

      attr_reader :item

      def initialize(item, child_self:, foreign_key:)
        if Feature.auto_association
          item.send(:write_attribute, foreign_key, item.try(:id)) if !item.try(:id).nil?
        end
        super
      end

    end

  end
end

