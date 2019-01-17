# frozen_string_literal: true

module Lic::Molinillo
  # @!visibility private
  module Delegates
    # Delegates all {Lic::Molinillo::ResolutionState} methods to a `#state` property.
    module ResolutionState
      # (see Lic::Molinillo::ResolutionState#name)
      def name
        current_state = state || Lic::Molinillo::ResolutionState.empty
        current_state.name
      end

      # (see Lic::Molinillo::ResolutionState#requirements)
      def requirements
        current_state = state || Lic::Molinillo::ResolutionState.empty
        current_state.requirements
      end

      # (see Lic::Molinillo::ResolutionState#activated)
      def activated
        current_state = state || Lic::Molinillo::ResolutionState.empty
        current_state.activated
      end

      # (see Lic::Molinillo::ResolutionState#requirement)
      def requirement
        current_state = state || Lic::Molinillo::ResolutionState.empty
        current_state.requirement
      end

      # (see Lic::Molinillo::ResolutionState#possibilities)
      def possibilities
        current_state = state || Lic::Molinillo::ResolutionState.empty
        current_state.possibilities
      end

      # (see Lic::Molinillo::ResolutionState#depth)
      def depth
        current_state = state || Lic::Molinillo::ResolutionState.empty
        current_state.depth
      end

      # (see Lic::Molinillo::ResolutionState#conflicts)
      def conflicts
        current_state = state || Lic::Molinillo::ResolutionState.empty
        current_state.conflicts
      end

      # (see Lic::Molinillo::ResolutionState#unused_unwind_options)
      def unused_unwind_options
        current_state = state || Lic::Molinillo::ResolutionState.empty
        current_state.unused_unwind_options
      end
    end
  end
end
