// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IStarFarm {
    function regNodeUser(address _user) external;
}

interface IERC20Burnable is IERC20Upgradeable {
    function burnFrom(address account, uint256 amount) external;
}

interface IBonus {
    function getlockRatio() view external returns (uint256);
    function getlockAddress() view external returns (address);
    function addTotalAmount(uint256) external;
}

interface IAirdrop {
    function setUser(address _user, uint256 _type) external;
}

contract StarNode is ContextUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _nodeIds;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Burnable;

    struct Node {
        uint256 totalUnit;
        uint256 burn;
        uint256 award;
        uint256 withdraw;
        uint256 awardLp;
        uint256 withdrawLp;
        address owner;
        bytes4 code;
        uint256 fee;
        string name;
    }

    struct UserNode {
        uint256 award;
        uint256 withdraw;
        uint256 totalAward;
        uint256 awardLp;
        uint256 withdrawLp;
        uint256 totalAwardLp;
    }

    IBonus public Bonus;
    IERC20Burnable public rewardLpToken;
    IERC20Burnable public starToken;
    IStarFarm public starFarm;
    IAirdrop public Airdrop;
    address public bonusAddr;
    uint256 selfGain;      // self addtional gain 100 = 1%
    uint256 parentGain;    // parent addtional gain 100 = 1%
    uint256 public unitPrice;
    uint256 public leastUnit;
    uint256 public fee;
    uint256 public userNumber;
    uint256 public award;
    uint256 public awardLp;
    Node[] public nodes;

    mapping(address => uint256) public nodeInfo;
    mapping(address => address) public userInviter;
    mapping(address => address[]) public nodeUsers;
    mapping(address => UserNode) public awardNodeUsers;
    mapping(string => address[]) public nameUsers;
    mapping(string => mapping(address => uint256)) public nameUsersIndex;

    event SettleNode(address _user, uint256 _amount);
    event Received(address, uint);

    function initialize(address _starToken, address _bonus, address _rewardLpToken, uint256 _selfGain, uint256 _parentGain, uint256 _unitPrice, uint256 _leastUnit, uint256 _fee) public initializer {
        __StarNode_init(_starToken, _bonus, _rewardLpToken, _selfGain, _parentGain, _unitPrice, _leastUnit, _fee);
    }

    function __StarNode_init(address _starToken, address _bonus, address _rewardLpToken, uint256 _selfGain, uint256 _parentGain, uint256 _unitPrice, uint256 _leastUnit, uint256 _fee) internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __StarNode_init_unchained(_starToken, _bonus, _rewardLpToken, _selfGain, _parentGain, _unitPrice, _leastUnit, _fee);
    }

    function __StarNode_init_unchained(address _starToken, address _bonus, address _rewardLpToken, uint256 _selfGain, uint256 _parentGain, uint256 _unitPrice, uint256 _leastUnit, uint256 _fee) public onlyOwner {
        starToken = IERC20Burnable(_starToken);
        bonusAddr = _bonus;
        Bonus = IBonus(bonusAddr);
        _set(_selfGain, _parentGain, _unitPrice, _leastUnit, _rewardLpToken);
        fee = _fee;
    }

    function _set(uint256 _selfGain, uint256 _parentGain, uint256 _unitPrice, uint256 _leastUnit, address _rewardLpToken) internal {
        selfGain = _selfGain;
        parentGain = _parentGain;
        unitPrice = _unitPrice;
        leastUnit = _leastUnit;
        rewardLpToken = IERC20Burnable(_rewardLpToken);
    }

    function nodeGain(address _user) external view returns (uint256 _selfGain, uint256 _parentGain) {
        address _inviter = userInviter[_user];
        if (address(0) != _inviter) {
            return (selfGain, parentGain);
        }else{
            return (0, 0);
        }
    }

    function nodeLength() public view returns (uint256) {
        return nodes.length;
    }

    function getNodeUsers(address _user) public view returns (address[] memory) {
        return nodeUsers[_user];
    }

    function nodeUserLength(address _user) public view returns (uint256) {
        return nodeUsers[_user].length;
    }

    function nameUsersLength(string memory _name) public view returns (uint256) {
        return nameUsers[_name].length;
    }

    function getNode(address _user) public view returns(uint256 _totalUnit, uint256 _burn, uint256 _award, uint256 _withdraw, uint256 _awardLp, uint256 _withdrawLp, address _owner, uint256 _fee, string memory _nodeName) {
        _totalUnit = nodes[nodeInfo[_user]].totalUnit;
        _burn = nodes[nodeInfo[_user]].burn;
        _award = nodes[nodeInfo[_user]].award;
        _withdraw = nodes[nodeInfo[_user]].withdraw;
        _awardLp = nodes[nodeInfo[_user]].awardLp;
        _withdrawLp = nodes[nodeInfo[_user]].withdrawLp;
        _owner = nodes[nodeInfo[_user]].owner;
        _fee = nodes[nodeInfo[_user]].fee;
        _nodeName = nodes[nodeInfo[_user]].name;
    }

    function depositNode(uint256 _unit, uint256 _fee, string memory _name) external {
        address _user = _msgSender();
        require(userInviter[_user] == address(0), "User must not node user");
        require(_unit > 0, "Uint must greater than 0");
        uint256 _amount = _unit.mul(unitPrice);
        starToken.burnFrom(_user, _amount.mul(100 - fee).div(100));
        uint256 lockRatio = Bonus.getlockRatio();
        address lockAddr = Bonus.getlockAddress();
        if (nodes.length == 0 || nodes[nodeInfo[_user]].owner != _user) {    // New node.
            require(_unit >= leastUnit, "Less than minimum limit");
            nodes.push(Node(_unit, _amount, 0, 0, 0, 0, _user, getRndId(_user), _fee, _name));
            nodeInfo[_user] = nodes.length - 1;
            nameUsers[_name].push(_user);
            nameUsersIndex[_name][_user] = nameUsers[_name].length - 1;
            starToken.transferFrom(_user,lockAddr,_amount.mul(fee).div(100).mul(lockRatio).div(100));
            uint256 amountBonus = _amount.mul(fee).div(100).mul(100 - lockRatio).div(100);
            starToken.transferFrom(_user,bonusAddr,amountBonus);
            Bonus.addTotalAmount(amountBonus);
            userNumber = userNumber.add(1);
            Airdrop.setUser(_msgSender(),2);
        } else {
            starToken.transferFrom(_user,lockAddr,_amount.mul(fee).div(100).mul(lockRatio).div(100));
            uint256 amountBonus = _amount.mul(fee).div(100).mul(100 - lockRatio).div(100);
            starToken.transferFrom(_user,bonusAddr,amountBonus);
            Bonus.addTotalAmount(amountBonus);
            Node storage node =  nodes[nodeInfo[_user]];
            node.totalUnit = node.totalUnit.add(_unit);
            node.burn = node.burn.add(_amount);
        }
    }

    function regFromNode(address _inviter, bytes32 _inviteCode) external {
        address _user = _msgSender();
        require(userInviter[_user] == address(0), "User already registered");
        require(nodeInfo[_user] == 0 && nodes[0].owner != _user, "You are node master");
        require(nodeUserLength(_inviter) < nodes[nodeInfo[_inviter]].totalUnit, "Parent node is full");
        require(verifyInvitecode(_user, _inviter, _inviteCode), "Invalid invite code");
        if(nodes[nodeInfo[_inviter]].fee > 0){
            starToken.transferFrom(_user, nodes[nodeInfo[_inviter]].owner, nodes[nodeInfo[_inviter]].fee);
        }
        nodeUsers[_inviter].push(_user);
        userNumber = userNumber.add(1);
        userInviter[_user] = _inviter;
        starFarm.regNodeUser(_user);
        Airdrop.setUser(_user,2);
    }

    function settleNode(address _user, uint256 _parentAmount, uint256 _selfAmount, uint256 _parentAmountLp, uint256 _selfAmountLp) external onlyStarFarm {
        address _inviter = userInviter[_user];
        uint256 _amount = _parentAmount + _selfAmount;
        uint256 _amountLp = _parentAmountLp + _selfAmountLp;
        if(_inviter != address(0)){
            award = award.add(_amount);
            nodes[nodeInfo[_inviter]].award = nodes[nodeInfo[_inviter]].award.add(_amount);
            awardNodeUsers[_inviter].award = awardNodeUsers[_inviter].award.add(_parentAmount);
            awardNodeUsers[_inviter].totalAward = awardNodeUsers[_inviter].totalAward.add(_parentAmount);
            awardNodeUsers[_user].award = awardNodeUsers[_user].award.add(_selfAmount);
            awardNodeUsers[_user].totalAward = awardNodeUsers[_user].totalAward.add(_selfAmount);
            awardLp = awardLp.add(_amountLp);
            nodes[nodeInfo[_inviter]].awardLp = nodes[nodeInfo[_inviter]].awardLp.add(_amountLp);
            awardNodeUsers[_inviter].awardLp = awardNodeUsers[_inviter].awardLp.add(_parentAmountLp);
            awardNodeUsers[_inviter].totalAwardLp = awardNodeUsers[_inviter].totalAwardLp.add(_parentAmountLp);
            awardNodeUsers[_user].awardLp = awardNodeUsers[_user].awardLp.add(_selfAmountLp);
            awardNodeUsers[_user].totalAwardLp = awardNodeUsers[_user].totalAwardLp.add(_selfAmountLp);
            emit SettleNode(_inviter, _amount);
        }
    }

    function withdraw() external {
        address _inviter = userInviter[_msgSender()];
        if (address(0) == _inviter) {
            require(nodes[nodeInfo[_msgSender()]].owner == _msgSender(), "Invalid inviter");
            _inviter = _msgSender();
        }
        Node storage node =  nodes[nodeInfo[_inviter]];
        UserNode storage nodeusers =  awardNodeUsers[_msgSender()];
        uint256 userAward = nodeusers.award;
        node.withdraw = node.withdraw.add(userAward);
        nodeusers.withdraw = nodeusers.withdraw.add(userAward);
        nodeusers.award = 0;
        starToken.safeTransfer(_msgSender(), userAward);
        uint256 userAwardLp = nodeusers.awardLp;
        node.withdrawLp = node.withdrawLp.add(userAwardLp);
        nodeusers.withdrawLp = nodeusers.withdrawLp.add(userAwardLp);
        nodeusers.awardLp = 0;
        if(address(rewardLpToken) == address(0)){
            (bool success, ) = _msgSender().call{value:userAwardLp}("");
            require(success, "Transfer failed.");
        }else{
            starToken.safeTransfer(_msgSender(), userAwardLp);
        }
    }

    function getRndId(address _user) internal view returns (bytes4){
        bytes4 _randId = bytes4(keccak256(abi.encodePacked(block.coinbase, block.timestamp, _user)));
        return _randId;
    }

    function verifyInvitecode(address _self, address _inviter, bytes32 _inviteCode) internal view returns (bool _verified) {
        require(nodes[nodeInfo[_inviter]].owner == _inviter, "Invalid inviter");
        if (_inviteCode == keccak256(abi.encodePacked(nodes[nodeInfo[_inviter]].code, _self))) return true;
    }

    function setStarFarm(address _addr) public onlyOwner {
        require(address(0) != _addr, "Farm contract address cannot be empty");
        starFarm = IStarFarm(_addr);
    }

    function setStarToken(address _starToken) public onlyOwner {
        require(address(0) != _starToken, "Farm contract address cannot be empty");
        starToken = IERC20Burnable(_starToken);
    }

    function setBonusAddr(address _bonusAddr) public onlyOwner {
        require(address(0) != _bonusAddr, "Farm contract address cannot be empty");
        bonusAddr = _bonusAddr;
        Bonus = IBonus(bonusAddr);
    }

    function setAirdrop(address _addr) external onlyOwner {
        require(address(0) != _addr, "bonus address can not be address 0");
        Airdrop = IAirdrop(_addr);
    }

    function setParams(uint256 _selfGain, uint256 _parentGain, uint256 _unitPrice, uint256 _leastUnit, address _rewardLpToken) public onlyOwner {
        _set(_selfGain, _parentGain, _unitPrice, _leastUnit, _rewardLpToken);
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function setJoiningFee(uint256 _fee) public {
        require(_msgSender() == nodes[nodeInfo[_msgSender()]].owner, "You are not the node master");
        nodes[nodeInfo[_msgSender()]].fee = _fee;
    }

    function setName(string memory _name) public {
        address _user = _msgSender();
        require(_user == nodes[nodeInfo[_user]].owner, "You are not the node master");
        string memory oldName = nodes[nodeInfo[_user]].name;
        if(nameUsers[oldName].length > 1)
        nameUsers[oldName][nameUsersIndex[_name][_user].sub(1)] = nameUsers[oldName][nameUsers[_name].length-1];
        nameUsers[oldName].pop();
        nodes[nodeInfo[_user]].name = _name;
        nameUsers[_name].push(_user);
        nameUsersIndex[oldName][_user] = 0;
        nameUsersIndex[_name][_user] = nameUsers[_name].length;
    }

    function withdrawLp() public onlyOwner {
        if(address(rewardLpToken) == address(0)){
            (bool success, ) = _msgSender().call{value:address(this).balance}("");
            require(success, "user Transfer failed.");
        }else{
            rewardLpToken.safeTransfer(_msgSender(), rewardLpToken.balanceOf(address(this)));
        }
    }

    modifier onlyStarFarm() {
        require(_msgSender() == address(starFarm), "Only allowed from starfarm contract");
        _;
    }

    receive() external payable{
        emit Received(_msgSender(), msg.value);
    }
}
