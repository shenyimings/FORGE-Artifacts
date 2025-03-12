// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract JungleRoadToken is ERC20, Pausable {
    address public immutable multiSigWallet; // created by gnosis safe

    /**
     * @notice Require that the sender is the multiSigWallet.
     */
    modifier onlyMultiSigWallet() {
        require(msg.sender == multiSigWallet, "Why do you do that");
        _;
    }

    constructor(address _multiSigWallet) public ERC20("Jungle Road Token", "JGRD") {
        // 1000M total supply of tokens
        require(_multiSigWallet != address(0), "multiSigWallet cannot be the zero address");
        multiSigWallet = _multiSigWallet;

        _mint(_multiSigWallet, 1000000000 ether); // 1,000,000,000 ether
    }

    function pause() public onlyMultiSigWallet {
        _pause();
    }

    function unpause() public onlyMultiSigWallet {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
