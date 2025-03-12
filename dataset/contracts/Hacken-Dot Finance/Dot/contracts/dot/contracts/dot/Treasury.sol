// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

/*
*
* MIT License
* ===========
*
* Copyright (c) 2021 DotFinance
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

import "../library/pancakeswap/SafeBEP20.sol";
import "../library/WhitelistUpgradeable.sol";
import "../library/SafeToken.sol";
import "../zap/ZapBSC.sol";
import "../interfaces/IStakingRewards.sol";
import "../interfaces/IPancakeRouter02.sol";


contract Treasury is WhitelistUpgradeable {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint;
    using SafeToken for address;

    /* ========== CONSTANTS ============= */

    IPancakeRouter02 private constant ROUTER = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    address public constant REEF_BNB = 0xd63b5CecB1f40d626307B92706Df357709D05827;
    address public constant DOT_BNB = 0xDd5bAd8f8b360d76d12FdA230F8BAF42fe0022CF;
    address public constant USDT_BNB = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    address public constant BUSD_BNB = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    address public constant LINK_BNB = 0x824eb9faDFb377394430d2744fa7C42916DE3eCe;
    address public constant LIT_BNB = 0x1F37d4226d23d09044B8005c127C0517BD7e94fD;
    address public constant LINA_BUSD = 0xC5768c5371568Cf1114cddD52CAeD163A42626Ed;
    address public constant RAMP_BUSD = 0xE834bf723f5bDff34a5D1129F3c31Ea4787Bc76a;
    address public constant USDT_BUSD = 0x7EFaEf62fDdCCa950418312c6C91Aef321375A00;
    address public constant USDC_BUSD = 0x2354ef4DF11afacb85a5C7f98B624072ECcddbB1;
    address public constant DAI_BUSD = 0x66FDB2eCCfB58cF098eaa419e5EfDe841368e489;

    /* ========== STATE VARIABLES ========== */

    address public keeper;
    ZapBSC public zapBSC;
    address public pinkBNBPair;
    address public pinkPool;

    /* ========== EVENTS ========== */

    event SwappedPinkBnb(uint amount);
    event PinkBnbTrasnferred(address indexed keeper, address indexed pool, uint amount);

    /* ========== MODIFIERS ========== */

    modifier onlyKeeper {
        require(msg.sender == keeper || msg.sender == owner(), 'Treasury: caller is not the owner or keeper');
        _;
    }

    /* ========== INITIALIZER ========== */

    receive() external payable {}

    function initialize(address _keeper, ZapBSC _zapBSC, address _pinkBNBPair, address _pinkPool) external initializer {
        require(_keeper != address(0), "Treasury: keeper must be set");
        keeper = _keeper;
        require(address(_zapBSC) != address(0), "Treasury: zapBSC must be set");
        zapBSC = _zapBSC;
        require(_pinkBNBPair != address(0), "Treasury: pinkBNBPair must be set");
        pinkBNBPair = _pinkBNBPair;
        require(_pinkPool != address(0), "Treasury: pinkPool must be set");
        pinkPool = _pinkPool;
        __Ownable_init();
    }

    /* ========== VIEW FUNCTIONS ========== */

    function flips() public pure returns (address[11] memory) {
        return [REEF_BNB, DOT_BNB, USDT_BNB, BUSD_BNB, LINK_BNB, LIT_BNB, LINA_BUSD, RAMP_BUSD, USDT_BUSD, USDC_BUSD, DAI_BUSD];
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setKeeper(address _keeper) external onlyKeeper {
        require(_keeper != address(0), 'Treasury: invalid keeper address');
        keeper = _keeper;
    }

    function setPinkPool(address _pinkPool) external onlyOwner {
        require(_pinkPool != address(0), 'Treasury: invalid pinkPool address');
        pinkPool = _pinkPool;
    }

    function transferToPool(uint _amount) public onlyKeeper {
        require(_amount <= IBEP20(pinkBNBPair).balanceOf(address(this)), "Treasury: amount is too big");
        
        if (_amount > 0) {
            IBEP20(pinkBNBPair).safeTransfer(address(pinkPool), _amount);
            IStakingRewards(pinkPool).notifyRewardAmount(_amount);

            emit PinkBnbTrasnferred(keeper, pinkPool, _amount);
        }
    }

    function zapAssetsToPinkBNB(address asset, uint amount) public onlyKeeper returns (uint pinkBNBAmount) {
        require(asset == address(0) || isTokenExists(asset), "unknown asset");

        uint _initPinkBNBAmount = IBEP20(pinkBNBPair).balanceOf(address(this));

        if (asset == address(0)) {
            zapBSC.zapIn{ value : amount }(pinkBNBPair);
        }
        else if (keccak256(abi.encodePacked(IPancakePair(asset).symbol())) == keccak256("Cake-LP")) {
            if (IBEP20(asset).allowance(address(this), address(ROUTER)) == 0) {
                IBEP20(asset).safeApprove(address(ROUTER), type(uint).max);
            }

            IPancakePair pair = IPancakePair(asset);
            address token0 = pair.token0();
            address token1 = pair.token1();

            (uint amountToken0, uint amountToken1) = ROUTER.removeLiquidity(token0, token1, amount, 0, 0, address(this), block.timestamp);

            if (IBEP20(token0).allowance(address(this), address(zapBSC)) == 0) {
                IBEP20(token0).safeApprove(address(zapBSC), type(uint).max);
            }
            if (IBEP20(token1).allowance(address(this), address(zapBSC)) == 0) {
                IBEP20(token1).safeApprove(address(zapBSC), type(uint).max);
            }

            zapBSC.zapInToken(token0, amountToken0, pinkBNBPair);
            zapBSC.zapInToken(token1, amountToken1, pinkBNBPair);
        }
        else {
            if (IBEP20(asset).allowance(address(this), address(zapBSC)) == 0) {
                IBEP20(asset).safeApprove(address(zapBSC), type(uint).max);
            }

            zapBSC.zapInToken(asset, amount, pinkBNBPair);
        }

        pinkBNBAmount = IBEP20(pinkBNBPair).balanceOf(address(this)).sub(_initPinkBNBAmount);

        emit SwappedPinkBnb(pinkBNBAmount);
    }

    function zapAllAssetsToPinkBNB() public onlyKeeper {
        address[11] memory _flips = flips();
        for (uint i = 0; i < _flips.length; i++) {
            address flip = _flips[i];
            uint balance = IBEP20(flip).balanceOf(address(this));
            if (balance > 0) {
                zapAssetsToPinkBNB(flip, balance);
            }
        }
    }

    function zapSingleAssetAndTransfer(address _asset) public onlyKeeper {
        uint balance = IBEP20(_asset).balanceOf(address(this));
        if (balance > 0) {
            uint pinkBNBAmount = zapAssetsToPinkBNB(_asset, balance);
            transferToPool(pinkBNBAmount);
        }
    }

    function zapAllAssetsAndTransfer() external onlyKeeper {
        address[11] memory _flips = flips();
        for (uint i = 0; i < _flips.length; i++) {
            address flip = _flips[i];
            zapSingleAssetAndTransfer(flip);
        }
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function isTokenExists(address asset) private pure returns (bool exists) {
        address[11] memory _tokens = flips();
        for (uint i = 0; i < _tokens.length; i++) {
            address flip = _tokens[i];
            if (asset == flip) {
                exists = true;
            }
        }
    }
}
