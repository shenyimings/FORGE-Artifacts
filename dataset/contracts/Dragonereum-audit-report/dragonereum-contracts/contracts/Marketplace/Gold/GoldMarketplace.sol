pragma solidity 0.4.25;


import "../../Common/Upgradable.sol";
import "../../Common/SafeMath256.sol";
import "./GoldMarketplaceStorage.sol";
import "../../Gold/Gold.sol";

contract GoldMarketplace is Upgradable {
    using SafeMath256 for uint256;

    GoldMarketplaceStorage _storage_;
    Gold goldTokens;

    uint256 constant GOLD_DECIMALS = uint256(10) ** 18;


    function _calculateFullPrice(
        uint256 _price,
        uint256 _amount
    ) internal pure returns (uint256) {
        return _price.mul(_amount).div(GOLD_DECIMALS);
    }

    function _transferGold(address _to, uint256 _value) internal {
        goldTokens.remoteTransfer(_to, _value);
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a <= _b ? _a : _b;
    }

    function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        return b > a ? 0 : a.sub(b);
    }

    function _checkPrice(uint256 _value) internal pure {
        require(_value > 0, "price must be greater than 0");
    }

    function _checkAmount(uint256 _value) internal pure {
        require(_value > 0, "amount must be greater than 0");
    }

    function _checkActualPrice(uint256 _expected, uint256 _actual) internal pure {
        require(_expected == _actual, "wrong actual price");
    }

    // SELL

    function createSellOrder(
        address _user,
        uint256 _price,
        uint256 _amount
    ) external onlyController {
        _checkPrice(_price);
        _checkAmount(_amount);

        _transferGold(address(_storage_), _amount);

        _storage_.createSellOrder(_user, _price, _amount);
    }

    function cancelSellOrder(address _user) external onlyController {
        ( , , , uint256 _amount) = _storage_.orderOfSeller(_user);
        _storage_.transferGold(_user, _amount);
        _storage_.cancelSellOrder(_user);
    }

    function fillSellOrder(
        address _buyer,
        uint256 _value,
        address _seller,
        uint256 _expectedPrice,
        uint256 _amount
    ) external onlyController returns (uint256 price) {
        uint256 _available;
        ( , , price, _available) = _storage_.orderOfSeller(_seller);

        _checkAmount(_amount);
        require(_amount <= _available, "seller has no enough gold");
        _checkActualPrice(_expectedPrice, price);

        uint256 _fullPrice = _calculateFullPrice(price, _amount);
        require(_fullPrice > 0, "no free gold, sorry");
        require(_fullPrice <= _value, "not enough ether");

        _seller.transfer(_fullPrice);
        if (_value > _fullPrice) {
            _buyer.transfer(_value.sub(_fullPrice));
        }
        _storage_.transferGold(_buyer, _amount);

        _available = _available.sub(_amount);

        if (_available == 0) {
            _storage_.cancelSellOrder(_seller);
        } else {
            _storage_.updateSellOrder(_seller, price, _available);
        }
    }

    // BUY

    function () external payable onlyController {}

    function createBuyOrder(
        address _user,
        uint256 _value, // eth
        uint256 _price,
        uint256 _amount
    ) external onlyController {
        _checkPrice(_price);
        _checkAmount(_amount);

        uint256 _fullPrice = _calculateFullPrice(_price, _amount);
        require(_fullPrice == _value, "wrong eth value");

        address(_storage_).transfer(_value);

        _storage_.createBuyOrder(_user, _price, _amount);
    }

    function cancelBuyOrder(address _user) external onlyController {
        ( , address _buyer, uint256 _price, uint256 _amount) = _storage_.orderOfBuyer(_user);
        require(_buyer == _user, "user addresses are not equal");

        uint256 _fullPrice = _calculateFullPrice(_price, _amount);
        _storage_.transferEth(_user, _fullPrice);

        _storage_.cancelBuyOrder(_user);
    }

    function fillBuyOrder(
        address _seller,
        address _buyer,
        uint256 _expectedPrice,
        uint256 _amount
    ) external onlyController returns (uint256 price) {
        uint256 _needed;
        ( , , price, _needed) = _storage_.orderOfBuyer(_buyer);

        _checkAmount(_amount);
        require(_amount <= _needed, "buyer do not need so much");
        _checkActualPrice(_expectedPrice, price);

        uint256 _fullPrice = _calculateFullPrice(price, _amount);

        _transferGold(_buyer, _amount);
        _storage_.transferEth(_seller, _fullPrice);

        _needed = _needed.sub(_amount);

        if (_needed == 0) {
            _storage_.cancelBuyOrder(_buyer);
        } else {
            _storage_.updateBuyOrder(_buyer, price, _needed);
        }
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        _storage_ = GoldMarketplaceStorage(_newDependencies[0]);
        goldTokens = Gold(_newDependencies[1]);
    }
}
