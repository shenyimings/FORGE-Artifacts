// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import {Errors} from "../common/Errors.sol";
import {ERC4626} from "../tokens/ERC4626.sol";
import {IGToken} from "../interfaces/IGToken.sol";

//  ________  ________  ________
//  |\   ____\|\   __  \|\   __  \
//  \ \  \___|\ \  \|\  \ \  \|\  \
//   \ \  \  __\ \   _  _\ \  \\\  \
//    \ \  \|\  \ \  \\  \\ \  \\\  \
//     \ \_______\ \__\\ _\\ \_______\
//      \|_______|\|__|\|__|\|_______|

// gro protocol: https://github.com/groLabs/GSquared

/// @title FixedTokensCurve
/// @notice Token definition contract
///
///     ###############################################
///     GTranche Tokens specification
///     ###############################################
///
///     This contract allows us to modify the underpinnings of the tranche
///         without having to worry about changing the core logic. The implementation
///         beneath supports 3 underlying EIP-4626 compatible tokens, but this contract
///         can be modified to use any combination.
///     Tranche Tokens:
///         - One Senior and one Junior tranche, this should be left unchanged
///     Yield Tokens
///         - Define one address var. and one decimal var.
///             per asset in the tranche
///         - Modify the getYieldtoken and getYieldtokenDecimal functions
///             to reflect the number of tokens defined above.
///         - updated NO_OF_TOKENS to match above number
///
///     Disclaimer:
///     The tranche has only been tested with EIP-4626 compatible tokens,
///         but should in theory be able to work with any tokens as long as
///         custom logic is supplied in the getYieldTokenValue function.
///         The core logic that defines the relationship between the underlying
///         assets in the tranche is defined outside the scope of this contract
///         (see oracle/relation module). Also note that this contract assumes
///         that the 4626 token has the same decimals as its underlying token,
///         this is not guaranteed by EIP-4626 and would have to be modified in
///         case these to values deviate, but for the purpose of the token this
///         version intends to operate on, this is held true.
contract FixedTokensCurve {
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant DEFAULT_FACTOR = 1_000_000_000_000_000_000;

    // Tranches
    uint256 public constant NO_OF_TRANCHES = 2;

    // Yield tokens - 1 address + 1 decimal per token
    uint256 public constant NO_OF_TOKENS = 1;

    address internal immutable FIRST_TOKEN;
    uint256 internal immutable FIRST_TOKEN_DECIMALS;

    /*//////////////////////////////////////////////////////////////
                    STORAGE VARIABLES & TYPES
    //////////////////////////////////////////////////////////////*/

    // Accounting for total amount of yield tokens in the contract
    uint256[NO_OF_TOKENS] public tokenBalances;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogNewTrancheBalance(
        uint256[NO_OF_TRANCHES] balances,
        uint256 _utilisation
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address[] memory _yieldTokens) {
        FIRST_TOKEN = _yieldTokens[0];
        FIRST_TOKEN_DECIMALS = 10**ERC4626(_yieldTokens[0]).decimals();
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the underlying yield token by index
    /// @param _index index of desired token
    /// @dev this function needs to be modified if the number of tokens is changed
    /// @return yieldToken tranches underlying yield token at index
    function getYieldToken(uint256 _index)
        public
        view
        returns (ERC4626 yieldToken)
    {
        if (_index >= NO_OF_TOKENS) {
            revert Errors.IndexTooHigh();
        }
        return ERC4626(FIRST_TOKEN);
    }

    /// @notice Get the underlying yield tokens decimals by index
    /// @param _index index of desired token
    /// @dev this function needs to be modified if the number of tokens is changed
    /// @return decimals token decimals
    function getYieldTokenDecimals(uint256 _index)
        public
        view
        returns (uint256 decimals)
    {
        if (_index >= NO_OF_TOKENS) {
            revert Errors.IndexTooHigh();
        }
        return FIRST_TOKEN_DECIMALS;
    }

    /// @notice Get values of all underlying yield tokens
    /// @dev this function needs to be modified if the number of tokens is changed
    /// @return values Amount of underlying tokens of yield tokens
    function getYieldTokenValues()
        public
        view
        returns (uint256[NO_OF_TOKENS] memory values)
    {
        values[0] = getYieldTokenValue(0, tokenBalances[0]);
    }

    /// @notice Get the amount of yield tokens
    /// @param _index index of desired token
    /// @param _amount amount (common denominator) that we want
    ///     to convert to yield tokens
    /// @return get amount of yield tokens from amount
    /// @dev Note that this contract assumes that the underlying decimals
    ///     of the 4626 token and its yieldtoken is the same, which
    ///     isnt guaranteed by EIP-4626. The _amount variable is denoted in the
    ///     precision of the common denominator (1E18), return value is denoted in
    ///     the yield tokens decimals
    function getYieldTokenAmount(uint256 _index, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        return getYieldToken(_index).convertToShares(_amount);
    }

    /// @notice Get the value of a yield token in its underlying token
    /// @param _index index of desired token
    /// @param _amount amount of yield token that we want to convert
    /// @dev Note that this contract assumes that the underlying decimals
    ///     of the 4626 token and its yieldtoken is the same, which
    ///     isnt guaranteed by EIP-4626. The _amount variable is denoted in the
    ///     precision of the yield token, return value is denoted in the precision
    ///     of the common denominator (1E18)
    function getYieldTokenValue(uint256 _index, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        return
            (getYieldToken(_index).convertToAssets(_amount) * DEFAULT_FACTOR) /
            getYieldTokenDecimals(_index);
    }
}
