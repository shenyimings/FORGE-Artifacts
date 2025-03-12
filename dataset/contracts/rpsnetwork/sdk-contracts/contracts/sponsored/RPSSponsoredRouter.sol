// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IRPSSponsoredRaffle} from "./IRPSSponsoredRaffle.sol";
import {IRPSRouter} from "../interface/IRPSRouter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RPSRouter is IRPSRouter, Ownable {

    IRPSSponsoredRaffle public raffle;
    address public protocol;
    uint256 private constant HUNDRED_PERCENT = 10000;

    constructor(address _owner, address _protocol) Ownable(_owner) {
        protocol = _protocol;
    }

    function execute(
        bytes calldata data, 
        uint256 tradeAmount
    ) external payable {
        // Generating tickets
        raffle.executeTrade(tradeAmount, msg.sender);

        // Integration call
        (bool success,) = protocol.call{ value: msg.value}(data);
        require(success, "Call unsuccessful");
    }

    function setRaffleAddress(address _raffle) external onlyOwner {
        require(_raffle != address(0), "Zero address");
        require(address(raffle) == address(0), "RPS Raffle address can only be set once");
        raffle = IRPSSponsoredRaffle(_raffle);
    }

    function migrateProtocol(address _newProtocolAddress) external onlyOwner {
        require(_newProtocolAddress != address(0));
        require(protocol != _newProtocolAddress, "Provide a new protocol address");
        protocol = _newProtocolAddress;
        emit ProtocolMigrated(_newProtocolAddress);
    }
}