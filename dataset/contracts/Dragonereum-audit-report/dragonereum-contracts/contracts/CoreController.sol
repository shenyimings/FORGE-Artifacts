pragma solidity 0.4.25;

import "./Common/Upgradable.sol";
import "./Core.sol";
import "./Getter.sol";
import "./Treasury.sol";
import "./Distribution.sol";
import "./Common/SafeMath256.sol";


contract CoreController is Upgradable {
    using SafeMath256 for uint256;

    Core core;
    Treasury treasury;
    Getter getter;
    Distribution distribution;

    function _isDragonOwner(address _user, uint256 _id) internal view returns (bool) {
        return getter.isDragonOwner(_user, _id);
    }

    function _checkTheDragonIsNotInGladiatorBattle(uint256 _id) internal view {
        require(!getter.isDragonInGladiatorBattle(_id), "dragon participates in gladiator battle");
    }

    function _checkTheDragonIsNotOnSale(uint256 _id) internal view {
        require(!getter.isDragonOnSale(_id), "dragon is on sale");
    }

    function _checkTheDragonIsNotOnBreeding(uint256 _id) internal view {
        require(!getter.isBreedingOnSale(_id), "dragon is on breeding sale");
    }

    function _checkThatEnoughDNAPoints(uint256 _id) internal view {
        require(getter.isDragonBreedingAllowed(_id), "dragon has no enough DNA points for breeding");
    }

    function _checkDragonOwner(address _user, uint256 _id) internal view {
        require(_isDragonOwner(_user, _id), "not an owner");
    }

    function claimEgg(
        address _sender,
        uint8 _dragonType
    ) external onlyController returns (
        uint256 eggId,
        uint256 restAmount,
        uint256 lastBlock,
        uint256 interval
    ) {
        (restAmount, lastBlock, interval) = distribution.claim(_dragonType);
        eggId = core.createEgg(_sender, _dragonType);

        uint256 _goldReward = treasury.hatchingPrice();
        uint256 _goldAmount = treasury.remainingGold();
        if (_goldReward > _goldAmount) _goldReward = _goldAmount;
        treasury.giveGold(_sender, _goldReward);
    }

    // ACTIONS WITH OWN TOKEN

    function sendToNest(
        address _sender,
        uint256 _eggId
    ) external onlyController returns (bool, uint256, uint256, address) {
        require(!getter.isEggOnSale(_eggId), "egg is on sale");
        require(core.isEggOwner(_sender, _eggId), "not an egg owner");

        uint256 _hatchingPrice = treasury.hatchingPrice();
        treasury.takeGold(_hatchingPrice);
        if (getter.getDragonsAmount() > 2997) { // 2997 + 2 (in the nest) + 1 (just sent) = 3000 dragons without gold burning
            treasury.burnGold(_hatchingPrice.div(2));
        }

        return core.sendToNest(_eggId);
    }

    function breed(
        address _sender,
        uint256 _momId,
        uint256 _dadId
    ) external onlyController returns (uint256 eggId) {
        _checkThatEnoughDNAPoints(_momId);
        _checkThatEnoughDNAPoints(_dadId);
        _checkTheDragonIsNotOnBreeding(_momId);
        _checkTheDragonIsNotOnBreeding(_dadId);
        _checkTheDragonIsNotOnSale(_momId);
        _checkTheDragonIsNotOnSale(_dadId);
        _checkTheDragonIsNotInGladiatorBattle(_momId);
        _checkTheDragonIsNotInGladiatorBattle(_dadId);
        _checkDragonOwner(_sender, _momId);
        _checkDragonOwner(_sender, _dadId);
        require(_momId != _dadId, "the same dragon");

        return core.breed(_sender, _momId, _dadId);
    }

    function upgradeDragonGenes(
        address _sender,
        uint256 _id,
        uint16[10] _dnaPoints
    ) external onlyController {
        _checkTheDragonIsNotOnBreeding(_id);
        _checkTheDragonIsNotOnSale(_id);
        _checkTheDragonIsNotInGladiatorBattle(_id);
        _checkDragonOwner(_sender, _id);
        core.upgradeDragonGenes(_id, _dnaPoints);
    }

    function setDragonTactics(
        address _sender,
        uint256 _id,
        uint8 _melee,
        uint8 _attack
    ) external onlyController {
        _checkDragonOwner(_sender, _id);
        core.setDragonTactics(_id, _melee, _attack);
    }

    function setDragonName(
        address _sender,
        uint256 _id,
        string _name
    ) external onlyController returns (bytes32) {
        _checkDragonOwner(_sender, _id);

        uint256 _length = bytes(_name).length;
        uint256 _price = getter.getDragonNamePriceByLength(_length);

        if (_price > 0) {
            treasury.takeGold(_price);
        }

        return core.setDragonName(_id, _name);
    }

    function setDragonSpecialPeacefulSkill(address _sender, uint256 _id, uint8 _class) external onlyController {
        _checkDragonOwner(_sender, _id);
        core.setDragonSpecialPeacefulSkill(_id, _class);
    }

    function useDragonSpecialPeacefulSkill(address _sender, uint256 _id, uint256 _target) external onlyController {
        _checkDragonOwner(_sender, _id);
        _checkTheDragonIsNotInGladiatorBattle(_id);
        _checkTheDragonIsNotInGladiatorBattle(_target);
        core.useDragonSpecialPeacefulSkill(_sender, _id, _target);
    }

    function distributeLeaderboardRewards() external onlyController returns (
        uint256[10] dragons,
        address[10] users
    ) {
        core.updateLeaderboardRewardTime();
        uint256 _remainingGold = treasury.remainingGold();
        uint256[10] memory _rewards = core.getLeaderboardRewards(_remainingGold);

        dragons = core.getDragonsFromLeaderboard();
        uint8 i;
        for (i = 0; i < dragons.length; i++) {
            if (dragons[i] == 0) continue;
            users[i] = getter.ownerOfDragon(dragons[i]);
        }

        uint256 _reward;
        for (i = 0; i < users.length; i++) {
            if (_remainingGold == 0) break;
            if (users[i] == address(0)) continue;

            _reward = _rewards[i];
            if (_reward > _remainingGold) {
                _reward = _remainingGold;
            }
            treasury.giveGold(users[i], _reward);
            _remainingGold = _remainingGold.sub(_reward);
        }
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        core = Core(_newDependencies[0]);
        treasury = Treasury(_newDependencies[1]);
        getter = Getter(_newDependencies[2]);
        distribution = Distribution(_newDependencies[3]);
    }
}
