// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../lib/forge-std/src/Test.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "../../contracts/Token.sol";

interface IERC677Receiver {
    event TokenReceived(address from, uint256 amount, bytes data);

    function onTokenTransfer(address from, uint256 amount, bytes calldata data) external returns (bool success);
}

/*
    fake currency to test the main contract with
*/
contract FakePaymentToken is ERC20Permit {
    uint8 decimalPlaces;

    constructor(
        uint256 _initialSupply,
        uint8 _decimals
    ) ERC20Permit("FakePaymentToken") ERC20("FakePaymentToken", "FPT") {
        decimalPlaces = _decimals;
        _mint(msg.sender, _initialSupply);
    }

    /// @dev price definition and deal() function rely on proper handling of decimalPlaces. Therefore we need to test if decimalPlaces other than 18 work fine, too.
    function decimals() public view override returns (uint8) {
        return decimalPlaces;
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function transferAndCall(address receiver, uint amount, bytes calldata data) public returns (bool success) {
        transfer(receiver, amount);
        bool callSuccess = IERC677Receiver(receiver).onTokenTransfer(msg.sender, amount, data);
        return callSuccess;
    }
}
