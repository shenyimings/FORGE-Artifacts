pragma solidity ^0.6.0;

import "./DHedgeTokenV1.sol";

contract DHedgeTokenV2Example is DHedgeTokenV1 {
    bool private _upgradedToV2;
    uint256 internal _receivedEther;

    function __DHedgeTokenV2Example_init() public {
        require(!_upgradedToV2, "DHedgeTokenV2Example: already upgraded");
        __DHedgeTokenV2Example_init_unchained();
    }

    function __DHedgeTokenV2Example_init_unchained() internal {
        version = 2;
        _receivedEther = 0;
    }

    function brandNewFunction() public pure returns (string memory) {
        return "Hello";
    }

    //can receive ether
    function brandNewPayableFunction() public payable {
        _receivedEther += msg.value;
    }

    function receivedEther() public view returns (uint256) {
        return _receivedEther;
    }
}
