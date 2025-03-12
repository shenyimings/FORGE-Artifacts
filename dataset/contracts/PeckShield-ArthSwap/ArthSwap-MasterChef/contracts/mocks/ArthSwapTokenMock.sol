// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ArthSwapTokenMock is ERC20, Ownable {
    uint256 private _totalSupply;
    bool private _transferable;

    event BecameTransferable();

    constructor() public ERC20("Test Token", "TEST") Ownable() {
        _transferable = true;
        /// @notice Explain to an end user what this does
        /// @dev Explain to a developer any extra details
        /// @param Documents a parameter just like in doxygen (must be followed by parameter name)/// @notice Explain to an end user what this does
        /// @dev Explain to a developer any extra details
        /// @param Documents a parameter just like in doxygen (must be followed by parameter name);
    }

    modifier istransferable() {
        require(transferable() == true, "Can Not Transfer");
        _;
    }

    function transfer(address to, uint256 amount)
        public
        override
        istransferable
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override istransferable returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            allowance(sender, _msgSender()).sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function mint(address to, uint256 amount) public returns (bool) {
        _mint(to, amount);
        return true;
    }

    function transferable() public view returns (bool) {
        return _transferable;
    }

    function toTransferable() public onlyOwner returns (bool) {
        _toTransferable();
        return true;
    }

    function _toTransferable() internal onlyOwner {
        _transferable = true;
        emit BecameTransferable();
    }
}
