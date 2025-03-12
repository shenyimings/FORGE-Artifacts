pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './interfaces/IWETH.sol';
import './lib/Fabric.sol';

// import 'hardhat/console.sol';

contract ArkenStopLimit is Ownable, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using Address for address;

    bytes32 public constant FULFILLER_ADMIN = keccak256('FULFILLER_ADMIN');
    bytes32 public constant FULFILLER = keccak256('FULFILLER');

    // constant
    address public constant _ETH_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 constant MAX_INT = 2**256 - 1;

    address public _ARKEN_APPROVE_;
    address public _ARKEN_PAUSER_;
    address public _WETH_;
    uint64 public _VERSION_;

    // enum
    enum OrderStatus {
        NULL,
        CREATED,
        SUCCESS,
        CANCELLED
    }
    enum OrderType {
        STOP_LIMIT,
        LIMIT_ORDER
    }

    // data
    struct OrderKey {
        uint256 nonce;
        address srcToken;
        address dstToken;
        uint256 amountIn;
        uint256 startPrice;
        uint256 stopPrice;
        uint256 limitPrice;
        uint256 amountOutMin;
        uint256 expiredAt;
        OrderType orderType;
        bool isBuyOrder;
    }
    mapping(bytes32 => OrderStatus) orderStatusMapping;

    modifier onlyArkenPauser() {
        require(
            _ARKEN_PAUSER_ == _msgSender(),
            'Pause: caller is not the pauser'
        );
        _;
    }

    // event
    event OrderCreated(
        uint256 nonce,
        address owner,
        address srcToken,
        address dstToken,
        uint256 amountIn,
        uint256 startPrice,
        uint256 stopPrice,
        uint256 limitPrice,
        uint256 amountOutMin,
        uint256 expiredAt,
        OrderType orderType,
        bool isBuyOrder
    );
    event OrderSuccess(bytes32 orderHash, uint256 fulfillAmount);
    event OrderCancelled(bytes32 orderHash);

    event WETHUpdated(address newWETH);
    event ArkenApproveUpdated(address newArkenApproveAddress);
    event ArkenPauserUpdated(address newArkenPauserAddress);

    constructor(
        address _ownerAddress,
        address _arkenFulfillerAdmin,
        address _arkenApprove,
        address _arkenPauser,
        address _weth,
        uint64 _version
    ) {
        transferOwnership(_ownerAddress);
        _ARKEN_APPROVE_ = _arkenApprove;
        _ARKEN_PAUSER_ = _arkenPauser;
        _WETH_ = _weth;
        _VERSION_ = _version;
        _setupRole(FULFILLER_ADMIN, _arkenFulfillerAdmin);
        _setRoleAdmin(FULFILLER, FULFILLER_ADMIN);
    }

    receive() external payable {}

    fallback() external payable {}

    function createOrder(OrderKey memory orderKey)
        external
        payable
        whenNotPaused
    {
        bytes32 orderHash = keccak256(
            abi.encode(
                orderKey.nonce,
                msg.sender,
                orderKey.srcToken,
                orderKey.dstToken,
                orderKey.amountIn,
                orderKey.startPrice,
                orderKey.stopPrice,
                orderKey.limitPrice,
                orderKey.amountOutMin,
                orderKey.expiredAt,
                orderKey.orderType,
                orderKey.isBuyOrder
            )
        );

        require(
            orderStatusMapping[orderHash] == OrderStatus.NULL,
            'Failed to created order: incorrect status'
        );
        orderStatusMapping[orderHash] = OrderStatus.CREATED;

        {
            address execAddr = Fabric.getVault(orderHash);
            if (_ETH_ == orderKey.srcToken) {
                _wrapEther(_WETH_, address(this).balance);
                IERC20(_WETH_).safeTransfer(execAddr, orderKey.amountIn);
            } else {
                IERC20(orderKey.srcToken).safeTransferFrom(
                    msg.sender,
                    execAddr,
                    orderKey.amountIn
                );
            }
        }

        emit OrderCreated(
            orderKey.nonce,
            msg.sender,
            orderKey.srcToken,
            orderKey.dstToken,
            orderKey.amountIn,
            orderKey.startPrice,
            orderKey.stopPrice,
            orderKey.limitPrice,
            orderKey.amountOutMin,
            orderKey.expiredAt,
            orderKey.orderType,
            orderKey.isBuyOrder
        );
    }

    function fulfillOrder(
        address owner,
        address arkenDex,
        OrderKey memory orderKey,
        bytes calldata data
    ) external whenNotPaused onlyRole(FULFILLER) {
        bytes32 orderHash = keccak256(
            abi.encode(
                orderKey.nonce,
                owner,
                orderKey.srcToken,
                orderKey.dstToken,
                orderKey.amountIn,
                orderKey.startPrice,
                orderKey.stopPrice,
                orderKey.limitPrice,
                orderKey.amountOutMin,
                orderKey.expiredAt,
                orderKey.orderType,
                orderKey.isBuyOrder
            )
        );
        require(
            block.timestamp < orderKey.expiredAt,
            'Failed to fulfill order: order has already expired'
        );
        require(
            orderStatusMapping[orderHash] == OrderStatus.CREATED,
            'Failed to fulfill order: incorrect status'
        );
        orderStatusMapping[orderHash] = OrderStatus.SUCCESS;

        if (_ETH_ == orderKey.srcToken) {
            Fabric.executeVault(orderHash, IERC20(_WETH_), address(this));
            _increaseAllowance(_WETH_, _ARKEN_APPROVE_, orderKey.amountIn);
        } else {
            Fabric.executeVault(
                orderHash,
                IERC20(orderKey.srcToken),
                address(this)
            );
            _increaseAllowance(
                orderKey.srcToken,
                _ARKEN_APPROVE_,
                orderKey.amountIn
            );
        }

        uint256 beforeDstAmt = _getBalance(orderKey.dstToken, owner);

        arkenDex.functionCall(data);

        uint256 receivedAmt = _getBalance(orderKey.dstToken, owner) -
            beforeDstAmt;

        require(
            receivedAmt >= orderKey.amountOutMin,
            'Received token is not enough'
        );

        emit OrderSuccess(orderHash, receivedAmt);
    }

    function cancelOrder(OrderKey memory orderKey) external {
        bytes32 orderHash = keccak256(
            abi.encode(
                orderKey.nonce,
                msg.sender,
                orderKey.srcToken,
                orderKey.dstToken,
                orderKey.amountIn,
                orderKey.startPrice,
                orderKey.stopPrice,
                orderKey.limitPrice,
                orderKey.amountOutMin,
                orderKey.expiredAt,
                orderKey.orderType,
                orderKey.isBuyOrder
            )
        );
        require(
            orderStatusMapping[orderHash] == OrderStatus.CREATED,
            'Failed to cancel order: incorrect status'
        );
        orderStatusMapping[orderHash] = OrderStatus.CANCELLED;

        if (_ETH_ == orderKey.srcToken) {
            uint256 beforeBalance = _getBalance(_ETH_, msg.sender);
            uint256 balance = Fabric.executeVault(
                orderHash,
                IERC20(_WETH_),
                address(this)
            );

            _unwrapEther(_WETH_, balance);

            (bool success, ) = msg.sender.call{value: balance}('');
            require(success, 'Failed to send Ether');

            uint256 afterBalance = _getBalance(_ETH_, msg.sender);
            require(
                afterBalance > beforeBalance,
                'Failed to cancel order: received token is not enough'
            );
        } else {
            uint256 beforeBalance = _getBalance(orderKey.srcToken, msg.sender);
            Fabric.executeVault(
                orderHash,
                IERC20(orderKey.srcToken),
                msg.sender
            );
            uint256 afterBalance = _getBalance(orderKey.srcToken, msg.sender);
            require(
                afterBalance > beforeBalance,
                'Failed to cancel order: received token is not enough'
            );
        }

        emit OrderCancelled(orderHash);
    }

    function viewOrderStatus(bytes32 orderHash)
        external
        view
        returns (OrderStatus)
    {
        require(
            orderStatusMapping[orderHash] != OrderStatus.NULL,
            'order doesnt exist'
        );
        return orderStatusMapping[orderHash];
    }

    function _getBalance(address token, address account)
        internal
        view
        returns (uint256)
    {
        if (_ETH_ == token) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    function _increaseAllowance(
        address token,
        address spender,
        uint256 amount
    ) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (amount > allowance) {
            uint256 increaseAmount = MAX_INT - allowance;
            IERC20(token).safeIncreaseAllowance(spender, increaseAmount);
        }
    }

    function _wrapEther(address weth, uint256 amount) internal {
        IWETH(weth).deposit{value: amount}();
    }

    function _unwrapEther(address weth, uint256 amount) internal {
        IWETH(weth).withdraw(amount);
    }

    // update address
    function updateArkenApprove(address _arkenApprove) external onlyOwner {
        require(_arkenApprove != address(0), 'arken approve zero address');
        _ARKEN_APPROVE_ = _arkenApprove;
        emit ArkenApproveUpdated(_ARKEN_APPROVE_);
    }

    function updateArkenPauser(address _arkenPauser) external onlyOwner {
        require(_arkenPauser != address(0), 'arken pauser zero address');
        _ARKEN_PAUSER_ = _arkenPauser;
        emit ArkenPauserUpdated(_ARKEN_PAUSER_);
    }

    function updateWETH(address _weth) external onlyOwner {
        require(_weth != address(0), 'WETH zero address');
        _WETH_ = _weth;
        emit WETHUpdated(_WETH_);
    }

    function setPause(bool _paused) external onlyArkenPauser {
        if (_paused) _pause();
        else _unpause();
    }
}
