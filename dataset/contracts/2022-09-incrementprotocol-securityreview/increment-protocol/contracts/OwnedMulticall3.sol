// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

import {Multicall3} from "./utils/Multicall3.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract OwnedMulticall3 is Ownable, Multicall3 {
    function aggregate(Call[] calldata calls)
        public
        payable
        override
        onlyOwner
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        return super.aggregate(calls);
    }

    function tryAggregate(bool requireSuccess, Call[] calldata calls)
        public
        payable
        override
        onlyOwner
        returns (Result[] memory returnData)
    {
        return super.tryAggregate(requireSuccess, calls);
    }

    function tryBlockAndAggregate(bool requireSuccess, Call[] calldata calls)
        public
        payable
        override
        onlyOwner
        returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData)
    {
        return super.tryBlockAndAggregate(requireSuccess, calls);
    }

    function blockAndAggregate(Call[] calldata calls)
        public
        payable
        override
        onlyOwner
        returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData)
    {
        return super.blockAndAggregate(calls);
    }

    function aggregate3(Call3[] calldata calls)
        public
        payable
        override
        onlyOwner
        returns (Result[] memory returnData)
    {
        return super.aggregate3(calls);
    }

    function aggregate3Value(Call3Value[] calldata calls)
        public
        payable
        override
        onlyOwner
        returns (Result[] memory returnData)
    {
        return super.aggregate3Value(calls);
    }
}
