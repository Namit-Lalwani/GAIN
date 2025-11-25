import XCTest
@testable import GAIN

final class WorkoutStoreTests: XCTestCase {
    
    var store: WorkoutStore!
    
    override func setUp() {
        super.setUp()
        // Use a test instance or mock
        store = WorkoutStore.shared
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    // MARK: - ADD_WORKOUT Test
    func testAddWorkout() {
        let initialCount = store.records.count
        
        let workout = WorkoutRecord(
            templateName: "Test Workout",
            exercises: [
                WorkoutExerciseRecord(name: "Bench Press", sets: [
                    WorkoutSetRecord(reps: 8, weight: 80)
                ])
            ]
        )
        
        store.add(workout)
        
        XCTAssertEqual(store.records.count, initialCount + 1)
        XCTAssertEqual(store.records.first?.templateName, "Test Workout")
        XCTAssertEqual(store.records.first?.exercises.count, 1)
    }
    
    // MARK: - UPDATE_WORKOUT Test
    func testUpdateWorkout() {
        let workout = WorkoutRecord(
            templateName: "Original",
            exercises: []
        )
        
        store.add(workout)
        let id = workout.id
        
        var updated = workout
        updated.templateName = "Updated"
        updated.notes = "Updated notes"
        
        store.update(updated)
        
        let found = store.records.first { $0.id == id }
        XCTAssertEqual(found?.templateName, "Updated")
        XCTAssertEqual(found?.notes, "Updated notes")
    }
    
    // MARK: - DELETE_WORKOUT Test
    func testDeleteWorkout() {
        let workout = WorkoutRecord(templateName: "To Delete")
        store.add(workout)
        let id = workout.id
        let initialCount = store.records.count
        
        store.delete(id: id)
        
        XCTAssertEqual(store.records.count, initialCount - 1)
        XCTAssertNil(store.records.first { $0.id == id })
    }
}





