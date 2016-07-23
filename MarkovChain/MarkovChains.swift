//
//  MarkovChains.swift
//  MarkovChain
//
//  Created by Brad G. on 7/21/16.
//  Copyright © 2016 Brad G. All rights reserved.
//

import Foundation
import GameplayKit

public class MarkovChainMachine: GKStateMachine
{
    let random: GKRandom = GKARC4RandomSource()
    let mapping: [NSArray: [[Double: GKState]]]
    private(set) var stateBuffer: [GKState] = []
    
    required public init(initialStates: [GKState], mapping:[NSArray: [[Double: GKState]]])
    {
        let lookbehind = initialStates.count
        self.mapping = mapping
        var states: Set<GKState> = []
        for (key, value) in mapping
        {
            assert(key.count == lookbehind, "Number of elements in probability tables must be the same as number of initial states")
            let keysSet = Set(key as! [GKState])
            states.unionInPlace(keysSet)
            assert(round(value.reduce(0){$0 + $1.keys.first!} * 100)/100 == 1, "Proabilities must add up to 1")
            value.forEach{states.insert($0.values.first!)}
        }
        super.init(states: Array(states))
        self.stateBuffer = initialStates
        super.enterState(initialStates.last!.dynamicType)
    }
    
    func enterNextState() -> Bool
    {
        if let state = self.nextState()
        {
            return self.enterState(state)
        }
        return false
    }
    
    func nextState() -> AnyClass?
    {
        return self.stateForStateBuffer(self.stateBuffer)?.dynamicType
    }
    
    override final public func canEnterState(stateClass: AnyClass) -> Bool
    {
        if self.currentState == nil
        {
            return true
        }
        
        guard let states = self.possibleStatesForBuffer(self.stateBuffer) else { return false }
        
        let clss = states.reduce(Array<AnyClass>()){ $0 + [$1.values.first!.dynamicType] }
        return clss.contains{$0 == stateClass}
    }
    
    override final public func enterState(stateClass: AnyClass) -> Bool
    {
        guard super.enterState(stateClass) else { return false }
        guard let currentState = self.currentState else { fatalError() }
        self.stateBuffer.removeFirst()
        self.stateBuffer.append(currentState)
        return true
    }
    
    func reset()
    {
        let index = Int(arc4random_uniform(UInt32(mapping.keys.count)))
        let states = Array(mapping.keys)[index]
        self.stateBuffer = states  as! [GKState]
        self.enterState(self.stateBuffer.first!.dynamicType)
    }
    
    // MARK: - Private
    
    private func possibleStatesForBuffer(buffer: [GKState]) -> [[Double:GKState]]?
    {
        return mapping[NSArray(array: buffer)]
    }
    
    private func stateForStateBuffer(buffer: [GKState]) -> GKState?
    {
        guard let probabilites = self.possibleStatesForBuffer(buffer) else { return nil }
        let random = Double(self.random.nextUniform())
        var runningMax: Double = 0
        for probability in probabilites
        {
            let value = probability.keys.first!
            if random >= runningMax && random < runningMax + value
            {
                return probability.values.first!
            }
            runningMax += value
        }
        
        return nil
     }
    
    required convenience public init?(coder aDecoder: NSCoder)
    {
        if let initialState = aDecoder.decodeObjectForKey("stateBuffer") as? [GKState],
               mapping = aDecoder.decodeObjectForKey("mapping") as? [NSArray: [[Double: GKState]]]
        {
            self.init(initialStates: initialState, mapping: mapping)
        }
        else
        {
            return nil
        }
    }
    
    func encodeWithCoder(aCoder: NSCoder)
    {
        aCoder.encodeObject(self.stateBuffer, forKey: "stateBuffer")
        aCoder.encodeObject(self.mapping, forKey: "mapping")
    }
}




















