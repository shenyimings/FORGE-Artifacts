
pragma solidity ^0.8.6;

import "./ERC20WrapperGluwacoin.sol";

/**
 * @dev Example usage of {ERC20WrapperGluwacoin}.
 */
contract ExampleCoin is ERC20WrapperGluwacoin  {
    // note that `decimals` must match that of `token` or less
    function initialize(string memory name, string memory symbol, IERC20 token) public override {
        __ExampleCoin_init(name, symbol,token);
    }

    function __ExampleCoin_init(string memory name, string memory symbol, IERC20 token)
    internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20ETHless_init_unchained();
        __ERC20Reservable_init_unchained();
        __ERC20Wrapper_init_unchained(token);
        __ERC20WrapperGluwacoin_init_unchained();
    }
}