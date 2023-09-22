import HealthKit
import Combine
import SwiftUI

public enum HeartRateObservingCommand: String {
  case start
  case stop
  
  public static let messageIdentifier = "com.HeartRateObserver.message"
  
  public var value: String {
    rawValue
  }
}

public struct HeartRate: Hashable, Identifiable {
  public static let messageIdentifier = "com.HeartRateObserver.heartRate"
  public var id = UUID()
  public var value: Double
  public var date: Date
  
  public var int: Int {
    Int(value)
  }
}

public final class HeartRateObserver: NSObject, ObservableObject {
  
  @Published public var isAvailable = false
  
  public var observedSubject = PassthroughSubject<HeartRate?, Never>()
  
  private var healthStore: HKHealthStore?
  
  public override init() {
    
  }
}

extension HeartRateObserver {
  public func start() {
    
    guard HKHealthStore.isHealthDataAvailable() else {
      return
    }
    
    let newHealthStore = HKHealthStore()
    healthStore = newHealthStore
    
    guard
      let type = [HKObjectType.quantityType(forIdentifier: .heartRate)] as? Set<HKSampleType>
    else {
      return
    }
    
    isAvailable = true
    
    // request authorization to access heart rate data
    newHealthStore.requestAuthorization(toShare: type, read: type) { [weak self] success, error in
      guard success, error == nil else {
        self?.isAvailable = false
        return
      }
    }
    
    // process the queries
    process()
  }
  
  public func stop() {
    observedSubject.send(nil)
    healthStore = nil
  }
}

extension HeartRateObserver {
  
  private func process() {
    // Set up the predicate source from current device (Apple watch)
    let device = HKDevice.local()
    let predicate = HKQuery.predicateForObjects(from: [device])
    
    guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
      isAvailable = false
      return
    }
    
    let query = HKAnchoredObjectQuery(
      type: sampleType,
      predicate: predicate,
      anchor: nil,
      limit: HKObjectQueryNoLimit
    ) { query, samples, deletedObjects, anchor, error in
      samples?.forEach { sample in
        guard let sample = sample as? HKQuantitySample else {
          return
        }
        
        let heartRateUnit = HKUnit(from: "count/min")
        let value = sample.quantity.doubleValue(for: heartRateUnit)
        
        Task { @MainActor [weak self] in
          let heartRate = HeartRate(value: value, date: sample.startDate)
          self?.observedSubject.send(heartRate)
        }
      }
    }
    
    healthStore?.execute(query)
  }
  
}
