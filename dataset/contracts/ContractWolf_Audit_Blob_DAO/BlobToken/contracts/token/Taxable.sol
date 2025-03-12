// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20Mod.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Taxable is Ownable {
    // ==================== STRUCTURE ==================== //

    uint256 public tax = 5 * 1e18; // 5%
    uint256 public threshold = 10000 * 1e6;

    address public priceFeed;

    uint256 private HUNDRED = 100 * 1e18;

    uint256 public currentTaxAmount = 0;

    mapping(address => bool) public taxExempts;
    mapping(address => uint256) public taxPercentages;
    address[] taxReceiverList;

    address public routerAddress;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    mapping(address => bool) public dexAddress;
    address[] dexAddressList;

    // ==================== EVENTS ==================== //

    event AddDEXAddress(address dex);
    event RemoveDEXAddress(address dex);
    event UpdateTax(uint256 oldPercentage, uint256 newPercentage);
    event UpdateReceiverTax(
        address receiver,
        uint256 oldPercentage,
        uint256 newPercentage
    );
    event AddTaxReceiver(address receiver, uint256 percentage);
    event RemoveTaxReceiver(address receiver);

    // ==================== MODIFIERS ==================== //

    modifier isValidAddress(address account) {
        require(account != address(0), "Invalid address");
        _;
    }

    // ==================== FUNCTIONS ==================== //

    function getAllDexAddresses() external view returns (address[] memory) {
        return dexAddressList;
    }

    function getAllTaxReceivers() external view returns (address[] memory) {
        return taxReceiverList;
    }

    function addDEXAddress(address _dex) external onlyOwner {
        require(_dex != address(0), "Invalid DEX address");
        require(!dexAddress[_dex], "DEX already exists");
        dexAddress[_dex] = true;
        dexAddressList.push(_dex);

        emit AddDEXAddress(_dex);
    }

    function removeDEXAddress(uint _index) external onlyOwner {
        require(_index < dexAddressList.length);
        emit RemoveDEXAddress(dexAddressList[_index]);
        dexAddress[dexAddressList[_index]] = false;
        dexAddressList[_index] = dexAddressList[dexAddressList.length - 1];
        dexAddressList.pop();
    }

    function addTaxReceiver(
        address _receiver,
        uint256 _percentage
    ) external onlyOwner {
        require(taxPercentages[_receiver] == 0, "Receiver already exists");
        taxPercentages[_receiver] = _percentage;
        taxReceiverList.push(_receiver);

        emit AddTaxReceiver(_receiver, _percentage);
    }

    function updateReceiverTax(
        address _receiver,
        uint256 _percentage
    ) external onlyOwner {
        require(taxPercentages[_receiver] > 0);
        emit UpdateReceiverTax(
            _receiver,
            taxPercentages[_receiver],
            _percentage
        );
        taxPercentages[_receiver] = _percentage;
    }

    function removeTaxReceiver(uint256 _index) external onlyOwner {
        require(_index < taxReceiverList.length);
        emit RemoveTaxReceiver(taxReceiverList[_index]);
        taxPercentages[taxReceiverList[_index]] = 0;
        taxReceiverList[_index] = taxReceiverList[taxReceiverList.length - 1];
        taxReceiverList.pop();
    }

    function updateThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0, "Value must be greater than 0");
        threshold = _threshold;
    }

    function updateTax(uint256 _tax) external onlyOwner {
        require(_tax <= 10 * 1e18, "Tax should not be greater than 10 %");

        emit UpdateTax(tax, _tax);
        tax = _tax;
    }

    function getPrice() public view returns (uint256) {
        (, int price, , , ) = AggregatorV3Interface(priceFeed)
            .latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    function calculateFeeAmount(
        uint256 _amount,
        uint256 _fee
    ) public view returns (uint256) {
        return (_amount * _fee) / HUNDRED;
    }

    function calculateTaxAmount(uint256 _amount) public view returns (uint256) {
        return calculateFeeAmount(_amount, tax);
    }

    function calculateTransferAmount(
        uint256 _amount,
        uint256 _tax
    ) public pure returns (uint256) {
        return _amount - _tax;
    }

    function setPriceFeed(
        address _priceFeedAddress
    ) public onlyOwner isValidAddress(_priceFeedAddress) {
        priceFeed = _priceFeedAddress;
    }

    function setRewardAddress(
        address _rewardAddress
    ) external onlyOwner isValidAddress(_rewardAddress) {
        USDC = _rewardAddress;
    }

    function setRouter(
        address _routerAddress
    ) external onlyOwner isValidAddress(_routerAddress) {
        routerAddress = _routerAddress;
    }

    function addTaxExempts(
        address _user
    ) external onlyOwner isValidAddress(_user) {
        taxExempts[_user] = true;
    }

    function removeTaxExempts(
        address _user
    ) external onlyOwner isValidAddress(_user) {
        taxExempts[_user] = false;
    }

    function _swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _to
    ) internal {
        IERC20(_tokenIn).approve(routerAddress, _amountIn);

        address[] memory path;
        if (_tokenIn != address(USDC) && _tokenOut != address(USDC)) {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = USDC;
            path[2] = _tokenOut;
        } else {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        }

        // Make the swap
        IUniswapV2Router02(routerAddress)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amountIn,
                0,
                path,
                _to,
                block.timestamp + 10 minutes
            );
    }

    function _distribute() internal {
        for (uint256 i = 0; i < taxReceiverList.length; i++) {
            address account = taxReceiverList[i];
            uint256 toSendAmount = calculateFeeAmount(
                currentTaxAmount,
                taxPercentages[account]
            );

            _swap(address(this), USDC, toSendAmount, account);
        }

        currentTaxAmount = 0;
    }

    function _taxEqualsHundred() internal view returns (bool) {
        uint256 sum = 0;
        for (uint256 i = 0; i < taxReceiverList.length; i++) {
            address account = taxReceiverList[i];
            sum += taxPercentages[account];
        }

        return (sum == HUNDRED);
    }
}
