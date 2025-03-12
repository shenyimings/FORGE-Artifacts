pragma solidity 0.4.25;

import "../CoreController.sol";

contract CoreControllerV2 is CoreController {
    uint256 public additionalVariable;

    function additionalFunctionality(uint _add) public {
        additionalVariable += _add;
    }
}
