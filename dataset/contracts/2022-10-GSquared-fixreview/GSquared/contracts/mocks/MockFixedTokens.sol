// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import "../tokens/ERC4626.sol";

contract MockFixedTokens {
    uint256 constant DEFAULT_FACTOR = 1_000_000_000_000_000_000;
    bool constant JUNIOR_TRANCHE_ID = false;
    bool constant SENIOR_TRANCHE_ID = true;

    address immutable FIRST_TOKEN;

    uint256 immutable FIRST_TOKEN_DECIMALS;

    address internal immutable JUNIOR_TRANCHE;
    address internal immutable SENIOR_TRANCHE;

    uint256 public constant NO_OF_TOKENS = 1;
    uint256 public constant NO_OF_TRANCHES = 2;

    uint256[NO_OF_TOKENS] public token_balances;
    mapping(bool => uint256) public tranche_balances;

    constructor(address[] memory _yieldTokens, address[2] memory _trancheTokens)
    {
        FIRST_TOKEN = _yieldTokens[0];
        FIRST_TOKEN_DECIMALS = 10**ERC4626(_yieldTokens[0]).decimals();
        JUNIOR_TRANCHE = _trancheTokens[0];
        SENIOR_TRANCHE = _trancheTokens[1];
    }

    function getYieldToken(uint256 _index)
        public
        view
        returns (ERC4626 yieldToken)
    {
        require(_index < NO_OF_TOKENS);
        return ERC4626(FIRST_TOKEN);
    }

    function getYieldTokenDecimals(uint256 _index)
        internal
        view
        returns (uint256 decimals)
    {
        require(_index < NO_OF_TOKENS);
        return FIRST_TOKEN_DECIMALS;
    }

    function getYieldTokenValues()
        internal
        view
        returns (uint256[NO_OF_TOKENS] memory values)
    {
        for (uint256 i; i < NO_OF_TOKENS; ++i) {
            values[i] = getYieldTokenValue(i, token_balances[i]);
        }
    }

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
