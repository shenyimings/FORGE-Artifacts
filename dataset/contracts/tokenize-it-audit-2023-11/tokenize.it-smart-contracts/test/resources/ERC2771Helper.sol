// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../lib/forge-std/src/Test.sol";
import "@opengsn/contracts/src/forwarder/Forwarder.sol"; // chose specific version to avoid import error: yarn add @opengsn/contracts@2.2.5

// copied from openGSN IForwarder
struct ForwardRequest {
    address from;
    address to;
    uint256 value;
    uint256 gas;
    uint256 nonce;
    bytes data;
    uint256 validUntil;
}

contract ERC2771Helper is Test {
    using ECDSA for bytes32; // for verify with var.recover()

    /**
        @notice register domain separator and return the domain separator
        @dev can only be used when testing with forge, as it uses cheatcodes. For some reason, the forwarder contracts do not return the domain separator, which is fixed here.
    */
    function registerDomain(
        Forwarder forwarder,
        string calldata domainName,
        string calldata version
    ) public returns (bytes32) {
        // https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
        // use chainId, address, name for proper implementation.
        // opengsn suggests different contents: https://docs.opengsn.org/soldoc/contracts/forwarder/iforwarder.html#registerdomainseparator-string-name-string-version
        vm.recordLogs();
        forwarder.registerDomainSeparator(domainName, version); // simply uses address string as name

        Vm.Log[] memory logs = vm.getRecordedLogs();
        // the next line extracts the domain separator from the event emitted by the forwarder
        bytes32 domainSeparator = logs[0].topics[1]; // internally, the forwarder calls this domainHash in registerDomainSeparator. But expects is as domainSeparator in execute().
        console.log("domainSeparator", vm.toString(domainSeparator));
        require(forwarder.domains(domainSeparator), "Registering failed");
        return domainSeparator;
    }

    /** 
        @notice register request type, e.g. which function to call and which parameters to expect
        @dev return the request type
    */
    function registerRequestType(
        Forwarder forwarder,
        string calldata functionName,
        string calldata functionParameters
    ) public returns (bytes32) {
        vm.recordLogs();
        forwarder.registerRequestType(functionName, functionParameters);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        // the next line extracts the request type from the event emitted by the forwarder
        bytes32 requestType = logs[0].topics[1];
        console.log("requestType", vm.toString(requestType));
        require(forwarder.typeHashes(requestType), "Registering failed");
        return requestType;
    }

    /*
    helps to examine logs
    */
    function consoleLogLogs(Vm.Log[] calldata logs) public view {
        console.log("These events have been recorded:");
        for (uint256 i = 0; i < logs.length; i++) {
            console.log("Event ", i, ":");
            Vm.Log memory log = logs[i];
            for (uint256 j = 0; j < log.topics.length; j++) {
                console.log("topic", j, vm.toString(log.topics[j]));
            }
        }
    }
}
