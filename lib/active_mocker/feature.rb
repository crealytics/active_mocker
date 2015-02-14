module ActiveMocker
  class Feature
      class << self
        attr_accessor :auto_association

        def reset
          @auto_association = true
        end
      end
  end
end