//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";
import "./interfaces/IPaymentGateway.sol";
import "./FilswanOracle.sol";
import "./FilinkConsumer.sol";
import "./interfaces/IPriceFeed.sol";

/// @notice MCS payment contract, handles lock and unlock of tokens
contract SwanPayment is IPaymentMinimal, Initializable {
    address public constant NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address private _ERC20_TOKEN;

    address private _owner;
    address private _oracle;
    address private _priceFeed;

    address private _chainlinkOracle;

    uint256 private lockTime;
    mapping(string => TxInfo) private txMap;
    mapping(string => TxInfo) private txCarMap;

    // TODO: users can refund anytime (before unlock)
    // mapping(string => bool) dealUnlocked;

    function initialize(
        address owner,
        address ERC20_TOKEN,
        address oracle,
        address priceFeed,
        address chainlinkOracle
    ) public initializer {
        _owner = owner;
        _ERC20_TOKEN = ERC20_TOKEN;
        _oracle = oracle;
        _priceFeed = priceFeed;
        _chainlinkOracle = chainlinkOracle;
        lockTime = 5 days;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, "Caller is not the owner");
        _;
    }

    function setOracle(address oracle) public onlyOwner returns (bool) {
        _oracle = oracle;
        return true;
    }

    function setChainlinkOracle(address chainlinkOracle)
        public
        onlyOwner
        returns (bool)
    {
        _chainlinkOracle = chainlinkOracle;
        return true;
    }

    function setPriceFeed(address priceFeed) public onlyOwner returns (bool) {
        _priceFeed = priceFeed;
        return true;
    }

    function getLockedPaymentInfo(string calldata cId)
        public
        view
        override
        returns (TxInfo memory tx)
    {
        // default value is 0
        return txCarMap[cId];
    }

    event LockPayment(
        string id,
        address token,
        uint256 lockedFee,
        uint256 minPayment,
        address recipient,
        uint256 deadline,
        uint256 size,
        uint8 copyLimit
    );

    event UnlockPayment(
        string id,
        address token,
        uint256 cost,
        uint256 restToken,
        address recipient, // who receive the token
        address owner // who lock the token
    );

    event UnlockCarPayment(string dealId, string network, address recipient);

    event ExpirePayment(
        string id,
        address token,
        uint256 amount,
        address owner
    );

    event Refund(string cid, address owner, uint256 amount);

    /// @notice Deposits the amount of token for specific transaction
    /// @param param The transaction information for which to deposit balance
    /// @return Returns true for a successful deposit, false for an unsuccessful deposit
    function lockTokenPayment(lockPaymentParam calldata param)
        public
        override
        returns (bool)
    {
        require(
            !txMap[param.id]._isExisted && !txCarMap[param.id]._isExisted,
            "Payment of transaction is already locked"
        );
       
        require(
            param.minPayment > 0 && param.amount > param.minPayment,
            "payment should greater than min payment"
        );

        require(
            IERC20(_ERC20_TOKEN).allowance(msg.sender, address(this)) >=
                param.amount,
            "please approve spending token"
        );
        IERC20(_ERC20_TOKEN).transferFrom(
            msg.sender,
            address(this),
            param.amount
        );

        if (param.size > 0) {
            TxInfo storage t = txCarMap[param.id];
            t.owner = msg.sender;
            t.minPayment = param.minPayment;
            t.recipient = param.recipient;
            t.deadline = block.timestamp + param.lockTime;
            t.lockedFee = param.amount;
            t.token = _ERC20_TOKEN;
            t._isExisted = true;
            t.size = param.size;
            t.copyLimit = param.copyLimit;
            t.blockNumber = block.number;
            
            emit LockPayment(
                param.id,
                t.token,
                t.lockedFee,
                param.minPayment,
                param.recipient,
                t.deadline,
                t.size,
                t.copyLimit
            );
        } else {
            TxInfo storage t = txMap[param.id];
            t.owner = msg.sender;
            t.minPayment = param.minPayment;
            t.recipient = param.recipient;
            t.deadline = block.timestamp + param.lockTime;
            t.lockedFee = param.amount;
            t.token = _ERC20_TOKEN;
            t._isExisted = true;
            t.copyLimit = param.copyLimit;
            t.blockNumber = block.number;
        }

        return true;
    }

    /// @notice after the file expires (couple days) the file owner can unlock
    /// @param param data
    /// @return Returns true for a successful payment, false for an unsuccessful payment
    function unlockTokenPayment(unlockPaymentParam calldata param)
        public
        override
        returns (bool)
    {
        TxInfo storage t = txMap[param.id];
        require(t._isExisted, "Transaction does not exist");
        uint256 lockedFee = t.lockedFee;
        // if passed deadline, pay back to user
        if (block.timestamp > t.deadline) {
            require(
                t.owner == msg.sender,
                "Tx passed deadline, only owner can get locked tokens"
            );
            t._isExisted = false;
            t.minPayment = 0;
            t.lockedFee = 0;

            IERC20(_ERC20_TOKEN).transfer(t.owner, lockedFee);
            emit ExpirePayment(param.id, _ERC20_TOKEN, lockedFee, t.owner);
        }
        return true;
    }

    function unlockCarPayment(string calldata dealId, string calldata network, address recipient)
        public
        override
        returns (bool)
    {
        require(
            FilswanOracle(_oracle).isCarPaymentAvailable(dealId, network, recipient),
            "illegal unlock car action"
        );

        uint256 tokenAmount = 0;
        // get spend token amount
        uint256 serviceCost = FilinkConsumer(_chainlinkOracle).getPrice(dealId, network);

        // get cid list
        string[] memory cidList = FilswanOracle(_oracle).getCidList(dealId, network);

        if (serviceCost > 0) {
            tokenAmount = IPriceFeed(_priceFeed).consult(
                _ERC20_TOKEN,
                serviceCost
            );
            uint256 size = 0;
            for (uint8 i = 0; i < cidList.length; i++) {
                TxInfo storage t = txCarMap[cidList[i]];
                if (!t._isExisted) {
                    continue;
                } else {
                    size += t.size;
                }
            }

            require(size > 0, "file size should be greater than 0");

            uint256 unitPrice = tokenAmount / size;
            for (uint8 i = 0; i < cidList.length; i++) {
                TxInfo storage t = txCarMap[cidList[i]];
                if(t.copyLimit == 0) continue;
                uint256 cost = unitPrice * t.size;

                if (t.lockedFee < cost) {
                    t.lockedFee = 0;
                } else {
                    t.lockedFee = t.lockedFee - cost;
                }
                t.copyLimit = t.copyLimit - 1;
                
                t._isExisted = (t.lockedFee > 0);
            }

            IERC20(_ERC20_TOKEN).transfer(recipient, tokenAmount);
            //todo: add unlock event here
        }
        emit UnlockCarPayment(dealId, network, recipient);
        return true;
    }

    /// @notice refund existing, EXPIRED cids back to owners
    function refund(string[] memory cidList) public {
        for (uint8 i = 0; i < cidList.length; i++) {
            TxInfo storage t = txCarMap[cidList[i]];
            if (t._isExisted && block.timestamp > t.deadline) {
                t._isExisted = false;
                if (t.lockedFee > 0) {
                    IERC20(_ERC20_TOKEN).transfer(t.owner, t.lockedFee);
                    emit Refund(cidList[i], t.owner, t.lockedFee);
                }
            }
        }
    }
}