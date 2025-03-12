// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@amxx/hre/contracts/ENSReverseRegistration.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "./extensions/ERC1046Upgradeable.sol";
import "./extensions/ERC1363Upgradeable.sol";

/// @custom:security-contact security@p00ls.com
abstract contract P00lsTokenBase is
    ERC20VotesUpgradeable,
    ERC1046Upgradeable,
    ERC1363Upgradeable,
    MulticallUpgradeable
{
    function owner()
        public
        view
        virtual
        returns (address);

    /**
     * Admin
     */
    function setTokenURI(string calldata _tokenURI)
        external
    {
        require(owner() == msg.sender, "P00lsToken: restricted");
        _setTokenURI(_tokenURI);
    }

    function setName(address ensregistry, string calldata ensname)
        external
    {
        require(owner() == msg.sender, "P00lsToken: restricted");
        ENSReverseRegistration.setName(ensregistry, ensname);
    }

    /**
     * Internal override resolution
     */
    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._mint(account, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        virtual
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._burn(account, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
    }
}
