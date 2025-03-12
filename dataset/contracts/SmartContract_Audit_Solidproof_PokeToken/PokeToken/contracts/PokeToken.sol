// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Uniswap.sol";
import "./PokeERC20.sol";

abstract contract BPContract{
    function protect( address sender, address receiver, uint256 amount ) external virtual;
}

contract PokeToken is PokeERC20 {
    using SafeMath for uint256;

    uint256 constant public MAX_SUPPLY = 600 * 10**6 * 10**18;

    IUniswapV2Router02 public uniswapV2Router;

    address public uniswapV2Pair;
    address public TREASURY_ADDR;

    uint256 public sellFeeRate = 0;
    uint256 public buyFeeRate = 0;

    BPContract public BP;
    bool public bpEnabled;

    constructor(string memory name, string memory symbol, address _unirouter)
        PokeERC20(name, symbol)
    {
        TREASURY_ADDR = _msgSender();
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _unirouter
        );

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        _approve(address(this), address(uniswapV2Router), ~uint256(0));

        _mint(_msgSender(), MAX_SUPPLY);
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function setTreasury(address _address) external onlyOwner{
        TREASURY_ADDR = _address;
    }

    function setSellFeeRate(uint256 _value) external onlyOwner{
        require(_value < 8, "over sell");
        sellFeeRate = _value;
    }

    function setBuyFeeRate(uint256 _value) external onlyOwner{
        require(_value < 5, "over buy");
        buyFeeRate = _value;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if(bpEnabled){
            BP.protect(sender, recipient, amount);
        }
        uint256 transferFeeRate = recipient == uniswapV2Pair
            ? sellFeeRate
            : (sender == uniswapV2Pair ? buyFeeRate : 0);
        if (
            transferFeeRate > 0 &&
            sender != address(this) &&
            recipient != address(this) &&
            sender != TREASURY_ADDR
        ) {
            uint256 _fee = amount.mul(transferFeeRate).div(100);
            super._transfer(sender, TREASURY_ADDR, _fee);

            amount = amount.sub(_fee);
        }
        super._transfer(sender, recipient, amount);
    }

    function setBPAddrss(address _bp) external onlyOwner {
        require(address(BP)== address(0), "Can only be initialized once");
        BP = BPContract(_bp);
    }

    function setBpEnabled(bool _enabled) external onlyOwner {
        bpEnabled = _enabled;
    }
}