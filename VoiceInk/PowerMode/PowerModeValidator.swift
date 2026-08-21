import Foundation
import SwiftUI

enum PowerModeValidationError: Error, Identifiable {
    case emptyName
    case duplicateName(String)

    var id: String {
        switch self {
        case .emptyName: return "emptyName"
        case .duplicateName: return "duplicateName"
        }
    }

    var localizedDescription: String {
        switch self {
        case .emptyName:
            return "Power mode name cannot be empty."
        case .duplicateName(let name):
            return "A power mode with the name '\(name)' already exists."
        }
    }
}

struct PowerModeValidator {
    private let powerModeManager: PowerModeManager
    
    init(powerModeManager: PowerModeManager) {
        self.powerModeManager = powerModeManager
    }
    
    @MainActor
    func validateForSave(config: PowerModeConfig, mode: ConfigurationMode) -> [PowerModeValidationError] {
        var errors: [PowerModeValidationError] = []
        
        if config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        let isDuplicateName = powerModeManager.configurations.contains { existingConfig in
            if case .edit(let editConfig) = mode, existingConfig.id == editConfig.id {
                return false
            }
            return existingConfig.name == config.name
        }
        
        if isDuplicateName {
            errors.append(.duplicateName(config.name))
        }

        // Duplicate app/URL triggers across profiles are allowed — list
        // order decides priority, and AppPickerPopover already surfaces
        // overlaps with a soft "Also in:" badge. The old hard reject here
        // presented a second, contradictory mental model of the same
        // situation.

        return errors
    }
}

extension View {
    func powerModeValidationAlert(
        errors: [PowerModeValidationError],
        isPresented: Binding<Bool>
    ) -> some View {
        self.alert(
            "Cannot Save Power Mode", 
            isPresented: isPresented,
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                if let firstError = errors.first {
                    Text(firstError.localizedDescription)
                } else {
                    Text("Please fix the validation errors before saving.")
                }
            }
        )
    }
} 