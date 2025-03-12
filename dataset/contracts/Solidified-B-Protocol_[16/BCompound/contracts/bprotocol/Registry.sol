pragma solidity 0.5.16;

import { Ownable } from "@openzeppelin/contracts/ownership/Ownable.sol";
import { GnosisSafeProxy } from "./proxy/GnosisSafeProxy.sol";
import { IAvatar } from "./interfaces/IAvatar.sol";
import { Avatar } from "./avatar/Avatar.sol";

/**
 * @dev Registry contract to maintain Compound, BProtocol and avatar address.
 */
contract Registry is Ownable {

    // Compound Contracts
    address public comptroller;
    address public comp;
    address public cEther;

    // BProtocol Contracts
    address public pool;
    address public score;
    address public compVoter;
    address public bComptroller;


    // Avatar
    address public avatarImpl;

    // Owner => Avatar
    mapping (address => address) public avatarOf;

    // Avatar => Owner
    mapping (address => address) public ownerOf;

    address[] public avatars;

    // An Avatar can have multiple Delegatee
    // Avatar => Delegatee => bool
    mapping (address => mapping(address => bool)) public delegate;

    // dummy caller, for safer delegate and execute
    DummyCaller public dummyCaller;

    // (target, 4 bytes) => boolean. For each target address and function call, can avatar call it?
    // this is to support upgradable features in compound
    // calls that allow user to change collateral and debt size, and enter/exit market should not be listed
    mapping (address => mapping(bytes4 => bool)) public whitelistedAvatarCalls;

    event NewAvatar(address indexed avatar, address owner);
    event Delegate(address indexed delegator, address avatar, address delegatee);
    event RevokeDelegate(address indexed delegator, address avatar, address delegatee);
    event NewPool(address oldPool, address newPool);
    event NewScore(address oldScore, address newScore);
    event AvatarCallWhitelisted(address target, bytes4 functionSig, bool whitelist);

    constructor(
        address _comptroller,
        address _comp,
        address _cEther,
        address _pool,
        address _bComptroller,
        address _score,
        address _compVoter
    )
        public
    {
        comptroller = _comptroller;
        comp = _comp;
        cEther = _cEther;
        pool = _pool;
        bComptroller = _bComptroller;
        score = _score;
        compVoter = _compVoter;

        avatarImpl = address(new Avatar());
        dummyCaller = new DummyCaller();
    }

    function setPool(address newPool) external onlyOwner {
        require(newPool != address(0), "Registry: pool-address-is-zero");
        address oldPool = pool;
        pool = newPool;
        emit NewPool(oldPool, newPool);
    }

    function setScore(address newScore) external onlyOwner {
        require(newScore != address(0), "Registry: score-address-is-zero");
        address oldScore = score;
        score = newScore;
        emit NewScore(oldScore, newScore);
    }

    function setWhitelistAvatarCall(address target, bytes4 functionSig, bool list) external onlyOwner {
        whitelistedAvatarCalls[target][functionSig] = list;
        emit AvatarCallWhitelisted(target, functionSig, list);
    }

    function newAvatar() external returns (address) {
        return _newAvatar(msg.sender);
    }

    function getAvatar(address _owner) public returns (address) {
        require(_owner != address(0), "Registry: owner-address-is-zero");
        address _avatar = avatarOf[_owner];
        if(_avatar == address(0)) {
            _avatar = _newAvatar(_owner);
        }
        return _avatar;
    }

    function delegateAvatar(address delegatee) public {
        require(delegatee != address(0), "Registry: delegatee-address-is-zero");
        address _avatar = avatarOf[msg.sender];
        require(_avatar != address(0), "Registry: avatar-not-found");

        delegate[_avatar][delegatee] = true;
        emit Delegate(msg.sender, _avatar, delegatee);
    }

    function revokeDelegateAvatar(address delegatee) public {
        address _avatar = avatarOf[msg.sender];
        require(_avatar != address(0), "Registry: avatar-not-found");
        require(delegate[_avatar][delegatee], "Registry: not-delegated");

        delegate[_avatar][delegatee] = false;
        emit RevokeDelegate(msg.sender, _avatar, delegatee);
    }

    function delegateAndExecuteOnce(address delegatee, address payable target, bytes calldata data) external payable {
        // make sure there is an avatar
        getAvatar(msg.sender);
        delegateAvatar(delegatee);
        dummyCaller.execute.value(msg.value)(target, data);
        revokeDelegateAvatar(delegatee);
    }

    function _newAvatar(address _owner) internal returns (address) {
        require(avatarOf[_owner] == address(0), "Registry: avatar-exits-for-owner");
        // _owner should not be an avatar address
        require(ownerOf[_owner] == address(0), "Registry: cannot-create-an-avatar-of-avatar");

        // Deploy GnosisSafeProxy with the Avatar contract as logic contract
        address _avatar = _deployAvatarProxy(_owner);
        // Initialize Avatar
        IAvatar(_avatar).initialize(address(this), comp, compVoter);

        avatarOf[_owner] = _avatar;
        ownerOf[_avatar] = _owner;
        avatars.push(_avatar);
        emit NewAvatar(_avatar, _owner);
        return _avatar;
    }

    function _deployAvatarProxy(address _owner) internal returns (address proxy) {
        bytes32 salt = keccak256(abi.encodePacked(_owner));
        bytes memory proxyCode = type(GnosisSafeProxy).creationCode;
        bytes memory deploymentData = abi.encodePacked(proxyCode, uint256(avatarImpl));

        assembly {
            proxy := create2(0, add(deploymentData, 0x20), mload(deploymentData), salt)
            if iszero(extcodesize(proxy)) { revert(0, 0) }
        }
    }

    function avatarLength() external view returns (uint256) {
        return avatars.length;
    }

    function avatarList() external view returns (address[] memory) {
        return avatars;
    }

    function doesAvatarExist(address _avatar) public view returns (bool) {
        return ownerOf[_avatar] != address(0);
    }

    function doesAvatarExistFor(address _owner) public view returns (bool) {
        return avatarOf[_owner] != address(0);
    }
}

contract DummyCaller {
    function execute(address target, bytes calldata data) external payable {
        (bool succ, bytes memory err) = target.call.value(msg.value)(data);
        require(succ, string(err));
    }
}
