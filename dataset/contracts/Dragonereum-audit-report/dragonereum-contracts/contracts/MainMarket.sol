pragma solidity 0.4.25;


import "./Common/Pausable.sol";
import "./Common/Upgradable.sol";
import "./Common/HumanOriented.sol";
import "./MarketplaceController.sol";
import "./Marketplace/Gold/GoldMarketplace.sol";
import "./Events.sol";
import "./Common/SafeMath256.sol";


contract MainMarket is Pausable, Upgradable, HumanOriented {
    using SafeMath256 for uint256;

    MarketplaceController public marketplaceController;
    GoldMarketplace goldMarketplace;
    Events events;

    // MARKETPLACE

    function _transferEth(
        address _from,
        address _to,
        uint256 _available,
        uint256 _required_,
        bool _isGold
    ) internal {
        uint256 _required = _required_;
        if (_isGold) {
            _required = 0;
        }

        _to.transfer(_required);
        if (_available > _required) {
            _from.transfer(_available.sub(_required));
        }
    }

    // EGG

    function buyEgg(
        uint256 _id,
        uint256 _expectedPrice,
        bool _isGold
    ) external onlyHuman whenNotPaused payable {
        (
            address _seller,
            uint256 _price,
            bool _success
        ) = marketplaceController.buyEgg(
            msg.sender,
            msg.value,
            _id,
            _expectedPrice,
            _isGold
        );
        if (_success) {
            _transferEth(msg.sender, _seller, msg.value, _price, _isGold);
            events.emitEggBought(msg.sender, _seller, _id, _price);
        } else {
            msg.sender.transfer(msg.value);
            events.emitEggRemovedFromSale(_seller, _id);
        }
    }

    function sellEgg(
        uint256 _id,
        uint256 _maxPrice,
        uint256 _minPrice,
        uint16 _period,
        bool _isGold
    ) external onlyHuman whenNotPaused {
        marketplaceController.sellEgg(msg.sender, _id, _maxPrice, _minPrice, _period, _isGold);
        events.emitEggOnSale(msg.sender, _id);
    }

    function removeEggFromSale(uint256 _id) external onlyHuman whenNotPaused {
        marketplaceController.removeEggFromSale(msg.sender, _id);
        events.emitEggRemovedFromSale(msg.sender, _id);
    }

    // DRAGON

    function buyDragon(
        uint256 _id,
        uint256 _expectedPrice,
        bool _isGold
    ) external onlyHuman whenNotPaused payable {
        (
            address _seller,
            uint256 _price,
            bool _success
        ) = marketplaceController.buyDragon(
            msg.sender,
            msg.value,
            _id,
            _expectedPrice,
            _isGold
        );
        if (_success) {
            _transferEth(msg.sender, _seller, msg.value, _price, _isGold);
            events.emitDragonBought(msg.sender, _seller, _id, _price);
        } else {
            msg.sender.transfer(msg.value);
            events.emitDragonRemovedFromSale(_seller, _id);
        }
    }

    function sellDragon(
        uint256 _id,
        uint256 _maxPrice,
        uint256 _minPrice,
        uint16 _period,
        bool _isGold
    ) external onlyHuman whenNotPaused {
        marketplaceController.sellDragon(msg.sender, _id, _maxPrice, _minPrice, _period, _isGold);
        events.emitDragonOnSale(msg.sender, _id);
    }

    function removeDragonFromSale(uint256 _id) external onlyHuman whenNotPaused {
        marketplaceController.removeDragonFromSale(msg.sender, _id);
        events.emitDragonRemovedFromSale(msg.sender, _id);
    }

    // BREEDING

    function buyBreeding(
        uint256 _momId,
        uint256 _dadId,
        uint256 _expectedPrice,
        bool _isGold
    ) external onlyHuman whenNotPaused payable {
        (
            uint256 _eggId,
            address _seller,
            uint256 _price,
            bool _success
        ) = marketplaceController.buyBreeding(
            msg.sender,
            msg.value,
            _momId,
            _dadId,
            _expectedPrice,
            _isGold
        );
        if (_success) {
            events.emitEggCreated(msg.sender, _eggId);
            _transferEth(msg.sender, _seller, msg.value, _price, _isGold);
            events.emitDragonBreedingBought(msg.sender, _seller, _dadId, _price);
        } else {
            msg.sender.transfer(msg.value);
            events.emitDragonRemovedFromBreeding(_seller, _dadId);
        }
    }

    function sellBreeding(
        uint256 _id,
        uint256 _maxPrice,
        uint256 _minPrice,
        uint16 _period,
        bool _isGold
    ) external onlyHuman whenNotPaused {
        marketplaceController.sellBreeding(msg.sender, _id, _maxPrice, _minPrice, _period, _isGold);
        events.emitDragonOnBreeding(msg.sender, _id);
    }

    function removeBreedingFromSale(uint256 _id) external onlyHuman whenNotPaused {
        marketplaceController.removeBreedingFromSale(msg.sender, _id);
        events.emitDragonRemovedFromBreeding(msg.sender, _id);
    }

    // GOLD

    // SELL

    function fillGoldSellOrder(
        address _seller,
        uint256 _price,
        uint256 _amount
    ) external onlyHuman whenNotPaused payable {
        address(goldMarketplace).transfer(msg.value);
        uint256 _priceForOne = goldMarketplace.fillSellOrder(msg.sender, msg.value, _seller, _price, _amount);
        events.emitGoldSold(msg.sender, _seller, _amount, _priceForOne);
    }

    function createGoldSellOrder(
        uint256 _price,
        uint256 _amount
    ) external onlyHuman whenNotPaused {
        goldMarketplace.createSellOrder(msg.sender, _price, _amount);
        events.emitGoldSellOrderCreated(msg.sender, _price, _amount);
    }

    function cancelGoldSellOrder() external onlyHuman whenNotPaused {
        goldMarketplace.cancelSellOrder(msg.sender);
        events.emitGoldSellOrderCancelled(msg.sender);
    }

    // BUY

    function fillGoldBuyOrder(
        address _buyer,
        uint256 _price,
        uint256 _amount
    ) external onlyHuman whenNotPaused {
        uint256 _priceForOne = goldMarketplace.fillBuyOrder(msg.sender, _buyer, _price, _amount);
        events.emitGoldBought(msg.sender, _buyer, _amount, _priceForOne);
    }

    function createGoldBuyOrder(
        uint256 _price,
        uint256 _amount
    ) external onlyHuman whenNotPaused payable {
        address(goldMarketplace).transfer(msg.value);
        goldMarketplace.createBuyOrder(msg.sender, msg.value, _price, _amount);
        events.emitGoldBuyOrderCreated(msg.sender, _price, _amount);
    }

    function cancelGoldBuyOrder() external onlyHuman whenNotPaused {
        goldMarketplace.cancelBuyOrder(msg.sender);
        events.emitGoldBuyOrderCancelled(msg.sender);
    }

    // SKILL

    function buySkill(
        uint256 _id,
        uint256 _target,
        uint256 _expectedPrice,
        uint32 _expectedEffect
    ) external onlyHuman whenNotPaused {
        (
            address _seller,
            uint256 _price,
            bool _success
        ) = marketplaceController.buySkill(
            msg.sender,
            _id,
            _target,
            _expectedPrice,
            _expectedEffect
        );

        if (_success) {
            events.emitSkillBought(msg.sender, _seller, _id, _target, _price);
        } else {
            events.emitSkillRemovedFromSale(_seller, _id);
        }
    }

    function sellSkill(
        uint256 _id,
        uint256 _price
    ) external onlyHuman whenNotPaused {
        marketplaceController.sellSkill(msg.sender, _id, _price);
        events.emitSkillOnSale(msg.sender, _id);
    }

    function removeSkillFromSale(uint256 _id) external onlyHuman whenNotPaused {
        marketplaceController.removeSkillFromSale(msg.sender, _id);
        events.emitSkillRemovedFromSale(msg.sender, _id);
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        marketplaceController = MarketplaceController(_newDependencies[0]);
        goldMarketplace = GoldMarketplace(_newDependencies[1]);
        events = Events(_newDependencies[2]);
    }
}
