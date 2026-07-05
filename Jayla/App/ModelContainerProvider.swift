//
//  ModelContainerProvider.swift
//  Jayla
//
//  One shared ModelContainer for the whole app. Both the SwiftUI scene
//  and (later) the background notification delegate resolve the SAME
//  container from here — that's what lets a background write land in the
//  same store the UI reads. ModelContainer is Sendable, so this is safe
//  to touch from any thread; a ModelContext is not, and never leaves its
//  owner.
//
//  A VersionedSchema ships from v1 so future field additions are
//  lightweight migrations rather than a store wipe.
//

import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ActivityEvent.self, BabyProfile.self]
    }
}

enum JaylaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum ModelContainerProvider {
    static let shared: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: JaylaMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
