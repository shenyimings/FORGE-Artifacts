pragma solidity ^0.4.24;
/**
 * @title NonZero
 */
contract NonZero {

// Functions with this modifier fail if he
    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "address can't be empty");
        _;
    }

    modifier nonZeroValue() {
        require(msg.value > 0, "msg value must be greater than 0");
        _;
    }

}
