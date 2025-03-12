// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract DMock {
    struct MockCall {
        bytes data;
        bytes returnValue;
    }

    // Maps a method signature to its mock call definition
    mapping(bytes32 => MockCall) public mockCalls;

    // Fallback function to handle all calls
    // solhint-disable-next-line
    fallback(bytes calldata) external returns (bytes memory) {
        // Check if mock has been defined based on {sig,param} pair
        MockCall storage mockCall_ = mockCalls[keccak256(msg.data)];

        // else check if generic mock has been defined based on sig
        if (mockCall_.data.length <= 0) {
            mockCall_ = mockCalls[keccak256(abi.encodePacked(bytes4(msg.data)))];
        }

        // solhint-disable-next-line custom-errors
        require(mockCall_.data.length > 0, "DMock: method not mocked");

        // Return the mocked return value
        return mockCall_.returnValue;
    }

    // Function to set up a mock call, given method sig and parameters
    function mockCall(bytes memory data, bytes memory returnValue) public {
        mockCalls[keccak256(data)] = MockCall(data, returnValue);
    }

    // Function to set up a mock call, given just method sig
    function mockMethod(bytes4 sig, bytes memory returnValue) public {
        bytes memory data = abi.encodePacked(sig);
        mockCalls[keccak256(data)] = MockCall(data, returnValue);
    }

    // Function to clear mocked call
    function clearMockCall(bytes memory data) public {
        delete mockCalls[keccak256(data)];
    }

    // Function to clear mocked method call
    function clearMockMethodSig(bytes4 sig) public {
        bytes memory data = abi.encodePacked(sig);
        delete mockCalls[keccak256(data)];
    }
}
