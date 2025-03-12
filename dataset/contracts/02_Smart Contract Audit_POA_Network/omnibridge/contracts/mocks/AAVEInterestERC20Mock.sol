pragma solidity 0.7.5;

import "../upgradeable_contracts/modules/interest/AAVEInterestERC20.sol";

contract AAVEInterestERC20Mock is AAVEInterestERC20 {
    constructor(
        address _omnibridge,
        address _owner,
        uint256 _minAavePaid,
        address _aaveReceiver
    ) AAVEInterestERC20(_omnibridge, _owner, _minAavePaid, _aaveReceiver) {}

    function incentivesController() public pure override returns (IStakedTokenIncentivesController) {
        return IStakedTokenIncentivesController(0x00B2952e5FfC9737efee35De2912fAD143c7cA1F);
    }

    function stkAAVEToken() public pure override returns (address) {
        return 0x2F2B2FE9C08d39b1F1C22940a9850e2851F40f99;
    }

    function lendingPool() public pure override returns (ILendingPool) {
        return ILendingPool(0xDe4e2b5D55D2eE0F95b6D96C1BF86b45364e45B0);
    }
}
