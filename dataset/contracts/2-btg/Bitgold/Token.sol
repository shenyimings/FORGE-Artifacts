/*

╭━━╮╭━━┳━━━━┳━━━┳━━━┳╮╱╱╭━━━╮
┃╭╮┃╰┫┣┫╭╮╭╮┃╭━╮┃╭━╮┃┃╱╱╰╮╭╮┃
┃╰╯╰╮┃┃╰╯┃┃╰┫┃╱╰┫┃╱┃┃┃╱╱╱┃┃┃┃
┃╭━╮┃┃┃╱╱┃┃╱┃┃╭━┫┃╱┃┃┃╱╭╮┃┃┃┃
┃╰━╯┣┫┣╮╱┃┃╱┃╰┻━┃╰━╯┃╰━╯┣╯╰╯┃
╰━━━┻━━╯╱╰╯╱╰━━━┻━━━┻━━━┻━━━╯

https://www.bitgold.vip
https://x.com/bitgoldvip
https://t.me/bitgold_vip
*/


// SPDX-License-Identifier: No License
pragma solidity 0.8.19;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable2Step.sol";
import "./Initializable.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapV2Router02.sol";

contract Bitgold is ERC20, ERC20Burnable, Ownable2Step, Initializable {
    
    IUniswapV2Router02 public routerV2;
    address public pairV2;
    mapping (address => bool) public AMMPairs;
 
    event RouterV2Updated(address indexed routerV2);
    event AMMPairsUpdated(address indexed AMMPair, bool isPair);
 
    constructor()
        ERC20(unicode"Bitgold", unicode"BTG") 
    {
        address supplyRecipient = 0x43CF3ca7C6A452e5936ce63e3e010a72d62081b9;
        
        _mint(supplyRecipient, 210000000 * (10 ** decimals()) / 10);
        _transferOwnership(0x43CF3ca7C6A452e5936ce63e3e010a72d62081b9);
    }
    
    /*
        This token is not upgradeable, but uses both the constructor and initializer for post-deployment setup.
    */
    function initialize(address _router) initializer external {
        _updateRouterV2(_router);
    }

    receive() external payable {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    function _updateRouterV2(address router) private {
        routerV2 = IUniswapV2Router02(router);
        pairV2 = IUniswapV2Factory(routerV2.factory()).createPair(address(this), routerV2.WETH());
        
        _setAMMPair(pairV2, true);

        emit RouterV2Updated(router);
    }

    function setAMMPair(address pair, bool isPair) external onlyOwner {
        require(pair != pairV2, "DefaultRouter: Cannot remove initial pair from list");

        _setAMMPair(pair, isPair);
    }

    function _setAMMPair(address pair, bool isPair) private {
        AMMPairs[pair] = isPair;

        if (isPair) { 
        }

        emit AMMPairsUpdated(pair, isPair);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._afterTokenTransfer(from, to, amount);
    }
}
