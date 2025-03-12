pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../ExampleCoin.sol";

contract ExampleCoinMock is Initializable, ExampleCoin {

    constructor(
        string memory name,
        string memory symbol,
        IERC20 token
    )  {
        __ExampleCoinMock_init(name, symbol, token);
    }

    function __ExampleCoinMock_init(
        string memory name,
        string memory symbol,
        IERC20 token
    ) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20ETHless_init_unchained();
        __ERC20Reservable_init_unchained();
        __ERC20Wrapper_init_unchained(token);
        __ERC20WrapperGluwacoin_init_unchained();
    }


}