// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IEventAggregator {

    function buy(
        address who_,
        uint256 policyIndex_,
        uint256 amount_,
        uint256 fromWeek_,
        uint256 toWeek_,
        string calldata notes_
    ) external;

    function deposit(
        address who_,
        uint256 amount_
    ) external;

    function withdraw(
        address who_,
        uint256 requestIndex_,
        uint256 share_
    ) external;

    function withdrawPending(
        address who_,
        uint256 requestIndex_
    ) external;

    function withdrawReady(
        address who_,
        uint256 requestIndex_,
        bool succeeded_
    ) external;

    function refund(
        uint256 policyIndex_,
        uint256 week_,
        address who_,
        uint256 amount_
    ) external;

    function claim(
        uint256 policyIndex_,
        uint256 amount_,
        address receipient_
    ) external;

    function changePoolManager(
        address poolManager_
    ) external;

    function addToCommittee(address who_) external;

    function removeFromCommittee(address who_) external;

    function changeCommitteeThreshold(uint256 threshold_) external;

    function vote(
        uint256 requestIndex_,
        bool support_
    ) external;

    function execute(uint256 requestIndex_) external;
}
