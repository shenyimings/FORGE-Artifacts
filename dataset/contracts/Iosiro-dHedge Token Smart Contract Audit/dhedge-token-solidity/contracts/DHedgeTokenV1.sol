pragma solidity ^0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

// ---------------------------------------------------------------------
// dHedge DAO ERC20 Token - https://dhedge.org
//
// Symbol         : DHT
// Name           : dHedge DAO Token
// Decimals       : 18
// Total supply   : 100,000,000
// Version        : 1
//
// Notes          : This token is upgradable using CALLDELEGATE pattern (courtesy of https://openzeppelin.org/).
//                  It should NOT be accessed directly but through the proxy contract address using this contract's ABI.
// ---------------------------------------------------------------------

contract DHedgeTokenV1 is Initializable, ERC20BurnableUpgradeSafe {
    uint256 public version;

    function __DHedgeTokenV1_init(address initialAccount) public initializer {
        __Context_init_unchained();
        __ERC20_init_unchained("dHedge DAO Token", "DHT");
        __ERC20Burnable_init_unchained();
        __DHedgeTokenV1_init_unchained(initialAccount, 100000000 * (10**18));
    }

    function __DHedgeTokenV1_init_unchained(
        address initialAccount,
        uint256 initialBalance
    ) internal initializer {
        version = 1;

        _mint(initialAccount, initialBalance);
    }

    uint256[50] private __gap;
}
