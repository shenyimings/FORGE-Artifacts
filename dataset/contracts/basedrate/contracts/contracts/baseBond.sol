// SPDX-License-Identifier: MIT
//
// BasedRate
// website.: www.basedrate.io
// telegram.: https://t.me/BasedRate
//               _
//              (_)
//               |
//          ()---|---()
//               |
//               |
//        __     |     __
//       |\     /^\     /|
//         '..-'   '-..'
//           `-._ _.-`
//               `

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./libraries/Operator.sol";

contract BaseBond is ERC20Burnable, Operator {
    /**
     * @notice Constructs the BRATE Bond ERC-20 contract.
     */
    constructor() ERC20("BasedRate.io BOND", "BBOND") {}

    /**
     * @notice Operator mints baseRate bonds to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of baseRate bonds to mint to
     * @return whether the process has been done
     */
    function mint(
        address recipient_,
        uint256 amount_
    ) public onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(
        address account,
        uint256 amount
    ) public override onlyOperator {
        super.burnFrom(account, amount);
    }
}
