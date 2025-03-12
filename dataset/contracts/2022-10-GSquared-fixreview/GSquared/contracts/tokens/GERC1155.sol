// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;
import {ERC1155} from "../solmate/src/tokens/ERC1155.sol";
import {IGERC1155} from "../interfaces/IGERC1155.sol";
import "../common/Constants.sol";
import {ITokenLogic} from "../common/TokenCalculations.sol";

/// @title Gro extension of ERC1155
/// @notice Token definition contract
abstract contract GERC1155 is ERC1155, IGERC1155, Constants {
    /*///////////////////////////////////////////////////////////////
                       Storage values
    //////////////////////////////////////////////////////////////*/
    // Accounting for the total "value" (as defined in the oracle/relation module)
    //  of the tranches: True => Senior Tranche, False => Junior Tranche
    mapping(uint256 => uint256) public trancheBalances;
    mapping(uint256 => uint256) private _totalSupply;

    ITokenLogic public tokenLogic;

    constructor(ITokenLogic _tokenLogic) {
        tokenLogic = _tokenLogic;
    }

    /*///////////////////////////////////////////////////////////////
                       Mint burn external logic
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint tokens to an address
    /// @param account The address to mint tokens to
    /// @param id The token id to mint
    /// @param amount The amount to be minted
    /// @param factor The factor to be applied to the amount
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        uint256 factor
    ) internal {
        require(account != address(0), "mint: 0x");
        require(amount > 0, "Amount is zero.");
        uint256 factoredAmount = tokenLogic.applyFactor(amount, factor, true);
        // Update the tranche supply
        _beforeTokenTransfer(
            address(0),
            account,
            _asSingletonArray(id),
            _asSingletonArray(factoredAmount)
        );

        _mint(account, id, factoredAmount, "");
    }

    /// @notice Burn tokens from an account
    /// @param account Account to burn tokens from
    /// @param id Token ID
    /// @param amount Amount to burn
    /// @param factor The factor to be applied to the amount
    function burn(
        address account,
        uint256 id,
        uint256 amount,
        uint256 factor
    ) internal {
        require(account != address(0), "mint: 0x");
        require(amount > 0, "Amount is zero.");
        uint256 factoredAmount = tokenLogic.applyFactor(amount, factor, true);
        _beforeTokenTransfer(
            account,
            address(0),
            _asSingletonArray(id),
            _asSingletonArray(factoredAmount)
        );
        _burn(account, id, factoredAmount);
    }

    /*///////////////////////////////////////////////////////////////
                       Public views
    //////////////////////////////////////////////////////////////*/

    /// @notice uri function is not used for GERC1155
    function uri(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return "";
    }

    /// @notice Total amount of tokens in with a given id without applied factor
    /// @param id Token ID
    function totalSupplyBase(uint256 id)
        public
        view
        override
        returns (uint256)
    {
        return _totalSupply[id];
    }

    /// @notice Amount of token the user owns without factor applied
    /// @param account Address of the user
    /// @param id Token ID
    function balanceOfBase(address account, uint256 id)
        public
        view
        override
        returns (uint256)
    {
        return balanceOf[account][id];
    }

    /*///////////////////////////////////////////////////////////////
                       Internal logic
    //////////////////////////////////////////////////////////////*/
    /// @notice Internal hook to run before any token transfer to capture changes in total supply
    /// @param from Address of the sender
    /// @param to Address of the receiver
    /// @param ids Array of token IDs
    /// @param amounts Array of token amounts
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] -= amounts[i];
            }
        }
    }

    function _asSingletonArray(uint256 element)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
