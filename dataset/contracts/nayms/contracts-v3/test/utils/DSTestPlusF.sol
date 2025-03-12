// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import "forge-std/Test.sol";

import { IERC20 } from "src/erc20/IERC20.sol";

contract DSTestPlusF is Test {
    using stdStorage for StdStorage;

    function writeTokenBalance(
        address to,
        address from,
        address token,
        uint256 amount
    ) public {
        IERC20 tkn = IERC20(token);
        tkn.approve(address(from), amount);

        stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(to).checked_write(amount);

        assertEq(tkn.balanceOf(to), amount, "balance should INCREASE (after mint)");
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) public view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}
