// SPDX-License-Identifier: Unlicense
pragma solidity  >= 0.6.12;
import "./libs/BEP20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract SpaceshipToken is BEP20 {
    using SafeMath for uint256;
    uint256 public maxSupply = 100 * 10**6 * 10**18;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    uint256 public operationFee = 2;
    uint256 public mktFee = 2;
    uint256 public p2eFee = 2;
    address public p2eAddress;
    address public mktAddress;
    bool public feeEnabled = true;
    bool private isTakingFee = false;
    mapping(address => bool) public excludeFee;
    mapping (address => bool) public blacklist;

    constructor(string memory _name, string memory _symbol) BEP20(_name, _symbol ,maxSupply) {
        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), ~uint256(0));
    }

    function setP2eAddress(address _p2e, uint256 fee) external onlyOwner {
        p2eAddress = _p2e;
        p2eFee = fee;
    }

    function setMktAddress(address _mkt, uint256 fee) external onlyOwner {
        mktAddress = _mkt;
        mktFee = fee;
    }
    
    function setOperationFee(uint256 _fee) external onlyOwner {
        operationFee = _fee;
    }

    function addBlacklist(address b, bool enable) external onlyOwner {
        blacklist[b] = enable;
    }
    function addExcludeFee(address b, bool enable) external onlyOwner {
        excludeFee[b] = enable;
    }

    function swapTokensForEthAndSend(uint256 tokenAmount, address to) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            to,
            block.timestamp
        );
    }

    function _transfer( address sender, address recipient, uint256 amount ) internal virtual override {
        require(!blacklist[sender] && !blacklist[recipient], "BLACKLISTED");
        
        if(recipient == uniswapV2Pair &&
            sender != address(this) &&
            sender != owner() &&
            !excludeFee[sender] &&
            feeEnabled && isTakingFee == false){

            isTakingFee = true;
            
            uint256 _p2eFee = amount.mul(p2eFee).div(100);
            super._transfer(sender, p2eAddress, _p2eFee);

            uint256 _mktFee = amount.mul(mktFee).div(100);
            uint256 _operationFee = amount.mul(operationFee).div(100);
            super._transfer(sender, address(this), _mktFee.add(_operationFee));

            swapTokensForEthAndSend(_mktFee, mktAddress);
            swapTokensForEthAndSend(_operationFee, owner());

            amount = amount.sub(_operationFee.add(_p2eFee).add(_mktFee));
            isTakingFee = false;
        }
        super._transfer(sender, recipient, amount);
    }
}