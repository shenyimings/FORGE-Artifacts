// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;



/*  Provides counters that can only be incremented, decremented, or reset.
        - Example uses: to track the number of elements in a mapping, issuing ERC721 ids, or counting request ids.
        - Include with 'using Counters for Counters.Counter;'                                                    
*/
library Counters {
    
    struct Counter {
        
        /* This variable should never be directly accessed by users of the library: 
            - interactions must be restricted to the library's function.
            - As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add this feature.
        */
        uint256 _value; // default: 0
    }
    
    
    // Returns value held in counter.
    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }
    
    
    // Increments counter by 1.
    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }
    
    
    // Decrements (decreases) counter by 1.
    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }
    
    
    // Resets Counter to a null value of 0.
    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}