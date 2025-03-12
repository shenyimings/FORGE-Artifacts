pragma solidity 0.4.25;


import "../Getter.sol";

contract GetterMock is Getter {

    uint dragonAmount = 1;

    function getDragonsAmount() external view returns (uint256) {
        return dragonAmount;
    }

    function setDragonsAmount(uint _a) external {
        dragonAmount = _a;
    }

}
