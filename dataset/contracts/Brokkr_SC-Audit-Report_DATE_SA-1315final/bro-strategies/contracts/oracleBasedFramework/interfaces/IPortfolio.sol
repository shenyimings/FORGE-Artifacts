// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IInvestable.sol";

// Ideally this struct would contain NameValuePair[], however
// that would result in 'Copying of type struct memory[] memory to storage not yet supported'
// when this struct is pushed to a storage array
struct InvestableDesc {
    IInvestable investable;
    uint24 allocationPercentage;
    string[] keys;
    bytes[] values;
}

interface IPortfolio is IInvestable {
    error RebalancePercentageNot100();
    error InvestableAlreadyAdded();
    error InvestableNotYetAdded();
    error InvestableHasNonZeroAllocation();
    error RebalanceIncorrectAllocationsLength();

    event InvestableAdd(
        IInvestable investable,
        uint24[] newAllocations,
        NameValuePair[] params
    );
    event InvestableRemove(IInvestable investable, uint24[] newAllocations);
    event InvestableChange(IInvestable investable, NameValuePair[] params);
    event TargetInvestableAllocationsSet(uint24[] newAllocations);
    event Rebalance();

    function addInvestable(
        IInvestable investable,
        uint24[] calldata newAllocations,
        NameValuePair[] calldata params
    ) external;

    function removeInvestable(
        IInvestable investable,
        uint24[] calldata newAllocations
    ) external;

    function changeInvestable(
        IInvestable investable,
        NameValuePair[] calldata params
    ) external;

    function setTargetInvestableAllocations(uint24[] calldata newAllocations)
        external;

    function getInvestables()
        external
        view
        returns (InvestableDesc[] memory investableDescs);

    function rebalance(
        uint256 minimumDepositTokenAmountOut,
        NameValuePair[][] calldata depositParams,
        NameValuePair[][] calldata withdrawParams
    ) external;
}
