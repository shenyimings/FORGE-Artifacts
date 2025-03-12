/*
 _______  _______  _______          _________   ______   _______  _______  _______ 
(  ____ \(  ____ \(  ___  )|\     /|\__   __/  (  __  \ (  ___  )(  ____ \(  ____ \
| (    \/| (    \/| (   ) || )   ( |   ) (     | (  \  )| (   ) || (    \/| (    \/
| (_____ | |      | |   | || |   | |   | |     | |   ) || |   | || |      | (__    
(_____  )| |      | |   | || |   | |   | |     | |   | || |   | || | ____ |  __)   
      ) || |      | |   | || |   | |   | |     | |   ) || |   | || | \_  )| (      
/\____) || (____/\| (___) || (___) |   | |     | (__/  )| (___) || (___) || (____/\
\_______)(_______/(_______)(_______)   )_(     (______/ (_______)(_______)(_______/
                                                                                   
https://t.me/ScoutDoge_Channel

https://t.me/ScoutDoge_Official

 */
// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/uniswapv2.sol";

contract ScoutDoge is IERC20, Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct vote {
        uint256 token;
        uint256 usd;
    }
    enum swapModel {
        closeSwap,
        fallSwapToMarketing,
        fallSwapToCommunity,
        fallTokenToMarketing,
        fallTokenToCommunity,
        onlySwapMarketing,
        onlySwapCommunity
    }
    address marketingAddress;
    address communityAddresss;
    address usdtAddress = 0x55d398326f99059fF775485246999027B3197955;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    mapping(address => bool) private _Blacklist;

    uint256 private constant MAX = ~uint256(0);

    uint256 private _tTotal = 1000000 * 10**6 * 10**9;

    uint256 private _rTotal = (MAX - (MAX % _tTotal));

    uint256 private _tFeeTotal;

    string private _name = "ScoutDoge";
    string private _symbol = "SDOGE";
    uint8 private _decimals = 9;

    uint256 public _taxFee = 3;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee = 10;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public marketingDivisor = 4;

    uint256 public communityDivisor = 6;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    mapping(address => address) private _operate;
    mapping(address => EnumerableSet.AddressSet) private _operateOwner;
    mapping(address => vote) public _purchase;
    vote public _totalPurchase;

    uint256 public LiquifyNum;
    bool inSwapAndLiquify;

    swapModel SellType = swapModel.fallSwapToMarketing;
    address[] public swapRouter;
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        _rOwned[_msgSender()] = _rTotal;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        marketingAddress = 0x382bd0Bb032FE8aBCa42Ea61A1F6E6B974aa862C;
        communityAddresss = owner();

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingAddress] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function getUsdAmount(uint256 amountIn) public view returns (uint256) {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = usdtAddress;
        uint256[] memory amountOuts = uniswapV2Router.getAmountsOut(
            amountIn,
            path
        );
        return amountOuts[2];
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "transfer from the zero address");
        require(to != address(0), "transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!_Blacklist[from], "not allowed to transfer");
        require(!_Blacklist[to], "not allowed to transfer");

        if (LiquifyNum > 0 && from == uniswapV2Pair) {
            uint256 usdAmount = getUsdAmount(amount);
            _purchase[to].token += amount;
            _purchase[to].usd += usdAmount;

            _totalPurchase.token += amount;
            _totalPurchase.usd += usdAmount;
        }

        if (!inSwapAndLiquify && to == uniswapV2Pair) {
            if (LiquifyNum == 0) LiquifyNum = block.number;
            uint256 currentContractBalance = balanceOf(address(this));
            if (currentContractBalance > 0) {
                doSwapToken(currentContractBalance);
            }
        }

        bool takeFee = true;
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        _tokenTransfer(from, to, amount, takeFee);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(sender, recipient, tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(sender, recipient, tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(sender, recipient, tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(sender, recipient, tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(
        address sender,
        address recipient,
        uint256 tLiquidity
    ) private {
        if (tLiquidity > 0) {
            uint256 Rate = _getRate();
            uint256 tMarketing = (tLiquidity * marketingDivisor) /
                (marketingDivisor + communityDivisor);
            uint256 tCommunity = tLiquidity.sub(tMarketing);
            if (recipient == uniswapV2Pair) {
                doSell(Rate, tLiquidity, tMarketing, tCommunity);
            } else {
                _addToken(communityAddresss, Rate, tCommunity);
                if (
                    sender == uniswapV2Pair && _operate[recipient] != address(0)
                ) {
                    _addToken(marketingAddress, Rate, tMarketing / 2);
                    _addToken(_operate[recipient], Rate, tMarketing / 2);
                } else {
                    _addToken(marketingAddress, Rate, tMarketing);
                }
            }
        }
    }

    function doSell(
        uint256 Rate,
        uint256 tLiquidity,
        uint256 tMarketing,
        uint256 tCommunity
    ) private {
        if (
            SellType == swapModel.fallSwapToMarketing ||
            SellType == swapModel.fallSwapToCommunity
        ) {
            _addToken(address(this), Rate, tLiquidity);
        } else if (SellType == swapModel.fallTokenToMarketing) {
            _addToken(marketingAddress, Rate, tLiquidity);
        } else if (SellType == swapModel.fallTokenToCommunity) {
            _addToken(communityAddresss, Rate, tLiquidity);
        } else if (SellType == swapModel.onlySwapMarketing) {
            _addToken(address(this), Rate, tMarketing);
            _addToken(communityAddresss, Rate, tCommunity);
        } else if (SellType == swapModel.onlySwapCommunity) {
            _addToken(address(this), Rate, tCommunity);
            _addToken(marketingAddress, Rate, tMarketing);
        } else {
            _addToken(marketingAddress, Rate, tMarketing);
            _addToken(communityAddresss, Rate, tCommunity);
        }
    }

    function _addToken(
        address addr,
        uint256 rate,
        uint256 tAmount
    ) private {
        _rOwned[addr] = _rOwned[addr].add(tAmount.mul(rate));
        if (_isExcluded[addr]) _tOwned[addr] = _tOwned[addr].add(tAmount);
    }

    function doSwapToken(uint256 amount) private {
        if (
            SellType == swapModel.fallSwapToMarketing ||
            SellType == swapModel.onlySwapMarketing
        ) {
            swapTo(marketingAddress, amount);
        } else if (
            SellType == swapModel.fallSwapToCommunity ||
            SellType == swapModel.onlySwapCommunity
        ) {
            swapTo(communityAddresss, amount);
        }
    }

    function swapTo(address addr, uint256 amount) private lockTheSwap {
        _approve(address(this), address(uniswapV2Router), amount);
        if (swapRouter.length == 0) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = uniswapV2Router.WETH();

            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amount,
                0,
                path,
                addr,
                block.timestamp
            );
        } else {
            uniswapV2Router
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amount,
                    0,
                    swapRouter,
                    addr,
                    block.timestamp
                );
        }
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_liquidityFee).div(10**2);
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;

        _taxFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
    }

    function isBlocklist(address _addr) external view returns (bool) {
        return _Blacklist[_addr];
    }

    function setBlacklist(address[] memory _addrs) external {
        for (uint256 index = 0; index < _addrs.length; index++) {
            _Blacklist[_addrs[index]] = true;
        }
    }

    function disBlacklist(address[] memory _addrs) external {
        for (uint256 index = 0; index < _addrs.length; index++) {
            _Blacklist[_addrs[index]] = false;
        }
    }

    function invitePlayers(address addr) private {
        require(
            _operate[addr] == address(0) && _purchase[addr].token == 0,
            string(
                abi.encodePacked(
                    Strings.toHexString(uint160(addr), 20),
                    " Not a new user"
                )
            )
        );

        _operate[addr] = _msgSender();
        _operateOwner[_msgSender()].add(addr);
    }

    function manyInvitePlayers(address[] calldata addrs) external {
        for (uint256 index = 0; index < addrs.length; index++) {
            invitePlayers(addrs[index]);
        }
    }

    function getSubordinateSize(address addr) external view returns (uint256) {
        return _operateOwner[addr].length();
    }

    function getSubordinate(uint256 from, uint256 limit)
        external
        view
        returns (address[] memory addrs)
    {
        addrs = new address[](limit);
        EnumerableSet.AddressSet storage set = _operateOwner[_msgSender()];
        for (uint256 i = 0; i < limit; i++) {
            addrs[i] = set.at(from + i);
        }
    }

    function setSwapRouter(address[] memory path) external {
        swapRouter = path;
    }

    function disSwapRouter() external {
        swapRouter = new address[](0);
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
    }

    function setMarketingDivisor(uint256 divisor) external onlyOwner {
        marketingDivisor = divisor;
        _liquidityFee = marketingDivisor + communityDivisor;
    }

    function setCommunityDivisor(uint256 divisor) external onlyOwner {
        communityDivisor = divisor;
        _liquidityFee = marketingDivisor + communityDivisor;
    }

    function setMarketingAddress(address _addr) external onlyOwner {
        marketingAddress = _addr;
    }

    function setCommunityAddress(address _addr) external onlyOwner {
        communityAddresss = _addr;
    }

    function transferToAddressETH(address recipient, uint256 amount)
        external
        onlyOwner
    {
        payable(recipient).transfer(amount);
    }

    function setSellType(uint256 _type) external onlyOwner {
        SellType = swapModel(_type);
    }

    function getSellType() external view returns (uint8) {
        return uint8(SellType);
    }

    function transferToToken(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).transfer(recipient, amount);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}
}
