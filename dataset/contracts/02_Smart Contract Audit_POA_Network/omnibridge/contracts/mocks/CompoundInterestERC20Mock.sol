pragma solidity 0.7.5;

import "../upgradeable_contracts/modules/interest/CompoundInterestERC20.sol";

contract CompoundInterestERC20Mock is CompoundInterestERC20 {
    constructor(
        address _omnibridge,
        address _owner,
        uint256 _minCompPaid,
        address _compReceiver
    ) CompoundInterestERC20(_omnibridge, _owner, _minCompPaid, _compReceiver) {}

    function comptroller() public pure override returns (IComptroller) {
        return IComptroller(0x85e855b22F01BdD33eE194490c7eB16b7EdaC019);
    }

    function compToken() public pure override returns (IERC20) {
        return IERC20(0x6f51036Ec66B08cBFdb7Bd7Fb7F40b184482d724);
    }
}
