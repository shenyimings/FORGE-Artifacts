pragma solidity 0.4.25;

import "./Common/Upgradable.sol";
import "./Core.sol";
import "./Marketplace/BreedingMarketplace.sol";
import "./Marketplace/EggMarketplace.sol";
import "./Marketplace/DragonMarketplace.sol";
import "./Marketplace/Gold/GoldMarketplace.sol";
import "./Marketplace/SkillMarketplace.sol";
import "./Dragon/DragonStorage.sol";
import "./Egg/EggStorage.sol";
import "./Gold/Gold.sol";
import "./Getter.sol";
import "./Common/SafeMath256.sol";

contract MarketplaceController is Upgradable {
    using SafeMath256 for uint256;

    Core core;
    BreedingMarketplace breedingMarketplace;
    EggMarketplace eggMarketplace;
    DragonMarketplace dragonMarketplace;
    GoldMarketplace goldMarketplace;
    SkillMarketplace skillMarketplace;
    DragonStorage dragonStorage;
    EggStorage eggStorage;
    Gold goldTokens;
    Getter getter;

    // ACTIONS WITH OWN TOKEN

    function _isEggOwner(address _user, uint256 _tokenId) internal view returns (bool) {
        return _user == eggStorage.ownerOf(_tokenId);
    }

    function _isDragonOwner(address _user, uint256 _tokenId) internal view returns (bool) {
        return _user == dragonStorage.ownerOf(_tokenId);
    }

    function _checkOwner(bool _isOwner) internal pure {
        require(_isOwner, "not an owner");
    }

    function _checkEggOwner(uint256 _tokenId, address _user) internal view {
        _checkOwner(_isEggOwner(_user, _tokenId));
    }

    function _checkDragonOwner(uint256 _tokenId, address _user) internal view {
        _checkOwner(_isDragonOwner(_user, _tokenId));
    }

    function _compareBuyerAndSeller(address _buyer, address _seller) internal pure {
        require(_buyer != _seller, "seller can't be buyer");
    }

    function _checkTheDragonIsNotInGladiatorBattle(uint256 _id) internal view {
        require(!getter.isDragonInGladiatorBattle(_id), "dragon participates in gladiator battle");
    }

    function _checkIfBreedingIsAllowed(uint256 _id) internal view {
        require(getter.isDragonBreedingAllowed(_id), "dragon has no enough DNA points for breeding");
    }

    function _checkEnoughGold(uint256 _required, uint256 _available) internal pure {
        require(_required <= _available, "not enough gold");
    }

    function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        return b > a ? 0 : a.sub(b);
    }

    // MARKETPLACE

    function _transferGold(address _to, uint256 _value) internal {
        goldTokens.remoteTransfer(_to, _value);
    }

    // EGG

    function buyEgg(
        address _sender,
        uint256 _value,
        uint256 _id,
        uint256 _expectedPrice,
        bool _isGold
    ) external onlyController returns (address seller, uint256 price, bool success) {
        seller = eggMarketplace.sellerOf(_id);
        _compareBuyerAndSeller(_sender, seller);

        if (eggStorage.isApprovedOrOwner(this, _id) && _isEggOwner(seller, _id)) {
            uint256 _balance = goldTokens.balanceOf(_sender);
            price = eggMarketplace.buyToken(_id, _isGold ? _balance : _value, _expectedPrice, _isGold);
            eggStorage.transferFrom(seller, _sender, _id);
            if (_isGold) {
                _transferGold(seller, price);
            }
            success = true;
        } else {
            eggMarketplace.removeFromAuction(_id);
            success = false;
        }
    }

    function sellEgg(
        address _sender,
        uint256 _id,
        uint256 _maxPrice,
        uint256 _minPrice,
        uint16 _period,
        bool _isGold
    ) external onlyController {
        _checkEggOwner(_id, _sender);
        require(!core.isEggInNest(_id), "egg is in nest");
        eggStorage.remoteApprove(this, _id);
        eggMarketplace.sellToken(_id, _sender, _maxPrice, _minPrice, _period, _isGold);
    }

    function removeEggFromSale(
        address _sender,
        uint256 _id
    ) external onlyController {
        _checkEggOwner(_id, _sender);
        eggMarketplace.removeFromAuction(_id);
    }

    // DRAGON

    function buyDragon(
        address _sender,
        uint256 _value,
        uint256 _id,
        uint256 _expectedPrice,
        bool _isGold
    ) external onlyController returns (address seller, uint256 price, bool success) {
        seller = dragonMarketplace.sellerOf(_id);
        _compareBuyerAndSeller(_sender, seller);

        if (dragonStorage.isApprovedOrOwner(this, _id) && _isDragonOwner(seller, _id)) {
            uint256 _balance = goldTokens.balanceOf(_sender);
            price = dragonMarketplace.buyToken(_id, _isGold ? _balance : _value, _expectedPrice, _isGold);
            dragonStorage.transferFrom(seller, _sender, _id);
            if (_isGold) {
                _transferGold(seller, price);
            }
            success = true;
        } else {
            dragonMarketplace.removeFromAuction(_id);
            success = false;
        }
    }

    function sellDragon(
        address _sender,
        uint256 _id,
        uint256 _maxPrice,
        uint256 _minPrice,
        uint16 _period,
        bool _isGold
    ) external onlyController {
        _checkDragonOwner(_id, _sender);
        _checkTheDragonIsNotInGladiatorBattle(_id);
        require(breedingMarketplace.sellerOf(_id) == address(0), "dragon is on breeding sale");
        dragonStorage.remoteApprove(this, _id);

        dragonMarketplace.sellToken(_id, _sender, _maxPrice, _minPrice, _period, _isGold);
    }

    function removeDragonFromSale(
        address _sender,
        uint256 _id
    ) external onlyController {
        _checkDragonOwner(_id, _sender);
        dragonMarketplace.removeFromAuction(_id);
    }

    // BREEDING

    function buyBreeding(
        address _sender,
        uint256 _value,
        uint256 _momId,
        uint256 _dadId,
        uint256 _expectedPrice,
        bool _isGold
    ) external onlyController returns (uint256 eggId, address seller, uint256 price, bool success) {
        _checkIfBreedingIsAllowed(_momId);
        require(_momId != _dadId, "the same dragon");
        _checkDragonOwner(_momId, _sender);
        seller = breedingMarketplace.sellerOf(_dadId);
        _compareBuyerAndSeller(_sender, seller);

        if (getter.isDragonBreedingAllowed(_dadId) && _isDragonOwner(seller, _dadId)) {
            uint256 _balance = goldTokens.balanceOf(_sender);
            price = breedingMarketplace.buyToken(_dadId, _isGold ? _balance : _value, _expectedPrice, _isGold);
            eggId = core.breed(_sender, _momId, _dadId);
            if (_isGold) {
                _transferGold(seller, price);
            }
            success = true;
        } else {
            breedingMarketplace.removeFromAuction(_dadId);
            success = false;
        }
    }

    function sellBreeding(
        address _sender,
        uint256 _id,
        uint256 _maxPrice,
        uint256 _minPrice,
        uint16 _period,
        bool _isGold
    ) external onlyController {
        _checkIfBreedingIsAllowed(_id);
        _checkDragonOwner(_id, _sender);
        _checkTheDragonIsNotInGladiatorBattle(_id);
        require(dragonMarketplace.sellerOf(_id) == address(0), "dragon is on sale");
        breedingMarketplace.sellToken(_id, _sender, _maxPrice, _minPrice, _period, _isGold);
    }

    function removeBreedingFromSale(
        address _sender,
        uint256 _id
    ) external onlyController {
        _checkDragonOwner(_id, _sender);
        breedingMarketplace.removeFromAuction(_id);
    }

    // SKILL

    function buySkill(
        address _sender,
        uint256 _id,
        uint256 _target,
        uint256 _expectedPrice,
        uint32 _expectedEffect
    ) external onlyController returns (address seller, uint256 price, bool success) {
        if (dragonStorage.exists(_id)) {
            price = skillMarketplace.getAuction(_id);
            seller = dragonStorage.ownerOf(_id);
            _compareBuyerAndSeller(_sender, seller);
            _checkTheDragonIsNotInGladiatorBattle(_id);
            _checkTheDragonIsNotInGladiatorBattle(_target);

            require(price <= _expectedPrice, "wrong price");
            uint256 _balance = goldTokens.balanceOf(_sender);
            _checkEnoughGold(price, _balance);

            ( , , uint32 _effect) = getter.getDragonSpecialPeacefulSkill(_id);
            require(_effect >= _expectedEffect, "effect decreased");

            core.useDragonSpecialPeacefulSkill(seller, _id, _target);

            _transferGold(seller, price);
            success = true;
        } else {
            skillMarketplace.removeFromAuction(_id);
            success = false;
        }
    }

    function sellSkill(
        address _sender,
        uint256 _id,
        uint256 _price
    ) external onlyController {
        _checkDragonOwner(_id, _sender);
        _checkTheDragonIsNotInGladiatorBattle(_id);
        (uint8 _skillClass, , ) = getter.getDragonSpecialPeacefulSkill(_id);
        require(_skillClass > 0, "special peaceful skill is not yet set");

        skillMarketplace.sellToken(_id, _price);
    }

    function removeSkillFromSale(
        address _sender,
        uint256 _id
    ) external onlyController {
        _checkDragonOwner(_id, _sender);
        skillMarketplace.removeFromAuction(_id);
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        core = Core(_newDependencies[0]);
        dragonStorage = DragonStorage(_newDependencies[1]);
        eggStorage = EggStorage(_newDependencies[2]);
        dragonMarketplace = DragonMarketplace(_newDependencies[3]);
        breedingMarketplace = BreedingMarketplace(_newDependencies[4]);
        eggMarketplace = EggMarketplace(_newDependencies[5]);
        goldMarketplace = GoldMarketplace(_newDependencies[6]);
        skillMarketplace = SkillMarketplace(_newDependencies[7]);
        goldTokens = Gold(_newDependencies[8]);
        getter = Getter(_newDependencies[9]);
    }
}
