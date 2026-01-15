import Foundation

struct ProjectTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let folders: [TemplateFolderDefinition]
    let isBuiltIn: Bool
    
    static let builtInTemplates: [ProjectTemplate] = [
        PropertyInspectionTemplate,
        ConstructionProgressTemplate,
        RoofingInspectionTemplate,
        HVACServiceTemplate,
        PlumbingInspectionTemplate,
        ElectricalInspectionTemplate,
        LandscapingTemplate,
        GeneralContractorTemplate
    ]
    
    static let PropertyInspectionTemplate = ProjectTemplate(
        id: "property-inspection",
        name: "Property Inspection",
        description: "Standard property inspection with room-by-room documentation",
        icon: "house.fill",
        folders: [
            TemplateFolderDefinition(name: "Exterior - Front", type: .location),
            TemplateFolderDefinition(name: "Exterior - Back", type: .location),
            TemplateFolderDefinition(name: "Exterior - Sides", type: .location),
            TemplateFolderDefinition(name: "Roof", type: .location),
            TemplateFolderDefinition(name: "Living Room", type: .location),
            TemplateFolderDefinition(name: "Kitchen", type: .location),
            TemplateFolderDefinition(name: "Bedrooms", type: .location),
            TemplateFolderDefinition(name: "Bathrooms", type: .location),
            TemplateFolderDefinition(name: "Basement", type: .location),
            TemplateFolderDefinition(name: "Garage", type: .location),
            TemplateFolderDefinition(name: "Utilities", type: .location),
            TemplateFolderDefinition(name: "Issues Found", type: .custom)
        ],
        isBuiltIn: true
    )
    
    static let ConstructionProgressTemplate = ProjectTemplate(
        id: "construction-progress",
        name: "Construction Progress",
        description: "Track construction phases from start to finish",
        icon: "hammer.fill",
        folders: [
            TemplateFolderDefinition(name: "Pre-Construction", type: .phase),
            TemplateFolderDefinition(name: "Foundation", type: .phase),
            TemplateFolderDefinition(name: "Framing", type: .phase),
            TemplateFolderDefinition(name: "Rough-In (Electrical/Plumbing)", type: .phase),
            TemplateFolderDefinition(name: "Insulation", type: .phase),
            TemplateFolderDefinition(name: "Drywall", type: .phase),
            TemplateFolderDefinition(name: "Finishes", type: .phase),
            TemplateFolderDefinition(name: "Final Walkthrough", type: .phase),
            TemplateFolderDefinition(name: "Punch List", type: .custom)
        ],
        isBuiltIn: true
    )
    
    static let RoofingInspectionTemplate = ProjectTemplate(
        id: "roofing-inspection",
        name: "Roofing Inspection",
        description: "Comprehensive roof assessment documentation",
        icon: "house.lodge.fill",
        folders: [
            TemplateFolderDefinition(name: "Overview Shots", type: .location),
            TemplateFolderDefinition(name: "Shingles/Materials", type: .location),
            TemplateFolderDefinition(name: "Flashing", type: .location),
            TemplateFolderDefinition(name: "Gutters & Downspouts", type: .location),
            TemplateFolderDefinition(name: "Ventilation", type: .location),
            TemplateFolderDefinition(name: "Skylights", type: .location),
            TemplateFolderDefinition(name: "Damage Documentation", type: .custom),
            TemplateFolderDefinition(name: "Recommendations", type: .custom)
        ],
        isBuiltIn: true
    )
    
    static let HVACServiceTemplate = ProjectTemplate(
        id: "hvac-service",
        name: "HVAC Service",
        description: "HVAC system inspection and service documentation",
        icon: "thermometer.medium",
        folders: [
            TemplateFolderDefinition(name: "Outdoor Unit", type: .location),
            TemplateFolderDefinition(name: "Indoor Unit", type: .location),
            TemplateFolderDefinition(name: "Thermostat", type: .location),
            TemplateFolderDefinition(name: "Ductwork", type: .location),
            TemplateFolderDefinition(name: "Filters", type: .location),
            TemplateFolderDefinition(name: "Before Service", type: .phase),
            TemplateFolderDefinition(name: "After Service", type: .phase),
            TemplateFolderDefinition(name: "Readings & Measurements", type: .custom)
        ],
        isBuiltIn: true
    )
    
    static let PlumbingInspectionTemplate = ProjectTemplate(
        id: "plumbing-inspection",
        name: "Plumbing Inspection",
        description: "Plumbing system documentation and repairs",
        icon: "drop.fill",
        folders: [
            TemplateFolderDefinition(name: "Water Heater", type: .location),
            TemplateFolderDefinition(name: "Main Lines", type: .location),
            TemplateFolderDefinition(name: "Fixtures", type: .location),
            TemplateFolderDefinition(name: "Drains", type: .location),
            TemplateFolderDefinition(name: "Water Damage", type: .custom),
            TemplateFolderDefinition(name: "Repairs Made", type: .phase)
        ],
        isBuiltIn: true
    )
    
    static let ElectricalInspectionTemplate = ProjectTemplate(
        id: "electrical-inspection",
        name: "Electrical Inspection",
        description: "Electrical system assessment and documentation",
        icon: "bolt.fill",
        folders: [
            TemplateFolderDefinition(name: "Main Panel", type: .location),
            TemplateFolderDefinition(name: "Sub Panels", type: .location),
            TemplateFolderDefinition(name: "Outlets & Switches", type: .location),
            TemplateFolderDefinition(name: "Wiring", type: .location),
            TemplateFolderDefinition(name: "Safety Issues", type: .custom),
            TemplateFolderDefinition(name: "Code Violations", type: .custom)
        ],
        isBuiltIn: true
    )
    
    static let LandscapingTemplate = ProjectTemplate(
        id: "landscaping",
        name: "Landscaping",
        description: "Landscape design and maintenance documentation",
        icon: "leaf.fill",
        folders: [
            TemplateFolderDefinition(name: "Front Yard", type: .location),
            TemplateFolderDefinition(name: "Back Yard", type: .location),
            TemplateFolderDefinition(name: "Irrigation", type: .location),
            TemplateFolderDefinition(name: "Hardscape", type: .location),
            TemplateFolderDefinition(name: "Before", type: .phase),
            TemplateFolderDefinition(name: "During", type: .phase),
            TemplateFolderDefinition(name: "After", type: .phase)
        ],
        isBuiltIn: true
    )
    
    static let GeneralContractorTemplate = ProjectTemplate(
        id: "general-contractor",
        name: "General Contractor",
        description: "Flexible template for general contracting work",
        icon: "wrench.and.screwdriver.fill",
        folders: [
            TemplateFolderDefinition(name: "Site Overview", type: .location),
            TemplateFolderDefinition(name: "Materials", type: .custom),
            TemplateFolderDefinition(name: "Day 1", type: .phase),
            TemplateFolderDefinition(name: "Progress", type: .phase),
            TemplateFolderDefinition(name: "Completion", type: .phase),
            TemplateFolderDefinition(name: "Client Sign-off", type: .custom)
        ],
        isBuiltIn: true
    )
}

struct TemplateFolderDefinition: Codable, Identifiable {
    var id: String { name }
    let name: String
    let type: TemplateFolderType
}

enum TemplateFolderType: String, Codable {
    case location = "LOCATION"
    case phase = "PHASE"
    case custom = "CUSTOM"
    
    var folderType: FolderType {
        switch self {
        case .location: return .location
        case .phase: return .phase
        case .custom: return .custom
        }
    }
}
