// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./uniswap/IUniswapV2Router02.sol";
import "./uniswap/IUniswapV2Factory.sol";
import "./uniswap/IUniswapV2Pair.sol";
import "../custom-lib/Auth.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Shibml is IERC20, Auth {
    using SafeMath for uint256;

    address private constant DEAD = address(0xdead);
    address private constant ZERO = address(0);
    address private constant LOCK_ACCOUNT = address(0xBB97a6BEbbECCD1617e7b402AAE9E9688E1C98F8);
    /**
     * Token Assets
     * name, symbol, _decimals totalSupply
     * This will be defined when we deploy the contract.
     */
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply = 1_000_000_000 * (10 ** _decimals);  // 1 billion

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    /**
     * Mode & Fee
     * mode1(BuyTax: treasury=2%, reflection=3%, SellTax: treasury=2%, reflection=3%)
     * mode2(BuyTax: 0, SellTax: treasury=2%, reflection=2%, luck holder reward=2%)
     * mode3(BuyTax: auto burn supply=1%, reflections to all top 150 holders=3%, 
     *       SellTax: treasury=2%, reflection=3%)
     * mode4(BuyTax: 0, SellTax: 0)
     */
    uint8 public mode = 1;  // current mode
    struct Fee {
        uint8 treasury;
        uint8 reflection;
        uint8 lucky;
        uint8 burn;
        uint8 total;
    }
    // Mode 1
    Fee public mode1BuyTax = Fee({treasury: 2, reflection: 3, lucky: 0, burn: 0, total: 5});
    Fee public mode1SellTax = Fee({treasury: 2, reflection: 3, lucky: 0, burn: 0, total: 5});
    // Mode 2
    Fee public mode2BuyTax = Fee({treasury: 0, reflection: 0, lucky: 0, burn: 0, total: 0});
    Fee public mode2SellTax = Fee({treasury: 2, reflection: 2, lucky: 2, burn: 0, total: 6});
    // Mode 3
    Fee public mode3BuyTax = Fee({treasury: 0, reflection: 3, lucky: 0, burn: 1, total: 4});
    Fee public mode3SellTax = Fee({treasury: 2, reflection: 3, lucky: 0, burn: 0, total: 5});
    // Mode 4
    Fee public mode4BuyTax = Fee({treasury: 0, reflection: 0, lucky: 0, burn: 0, total: 0});
    Fee public mode4SellTax = Fee({treasury: 0, reflection: 0, lucky: 0, burn: 0, total: 0});

    Fee public buyTax;
    Fee public sellTax;

    address private treasuryAddress;

    IUniswapV2Router02 public UNISWAP_V2_ROUTER;
    address public UNISWAP_V2_PAIR;

    mapping(address => bool) public isFeeExempt;
    mapping(address => bool) public isReflectionExempt;

    mapping(address => bool) public isHolder;
    address[] public holders;
    uint256 public totalReflectionAmount;
    uint256 public topHolderReflectionAmount;

    // events
    event UpdateMode(uint8 mode);
    event Reflection(uint256 amountAdded, uint256 totalAmountAccumulated);
    event LuckyReward(address holder, uint256 amount);

    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor (string memory name_, string memory symbol_, uint8 decimals_) Auth(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;

        UNISWAP_V2_ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        UNISWAP_V2_PAIR = IUniswapV2Factory(UNISWAP_V2_ROUTER.factory()).createPair(address(this), UNISWAP_V2_ROUTER.WETH());
        _allowances[address(this)][address(UNISWAP_V2_ROUTER)] = _totalSupply;
        _allowances[address(this)][address(UNISWAP_V2_PAIR)] = _totalSupply;
        _allowances[address(this)][msg.sender] = _totalSupply;

        isFeeExempt[msg.sender] = true;
        isFeeExempt[treasuryAddress] = true;
        isFeeExempt[ZERO] = true;
        isFeeExempt[DEAD] = true;

        isReflectionExempt[address(this)] = true;
        isReflectionExempt[address(UNISWAP_V2_ROUTER)] = true;
        isReflectionExempt[UNISWAP_V2_PAIR] = true;
        isReflectionExempt[msg.sender] = true;
        isReflectionExempt[treasuryAddress] = true;
        isReflectionExempt[ZERO] = true;
        isReflectionExempt[DEAD] = true;

        buyTax = mode1BuyTax;
        sellTax = mode1SellTax;

        uint256 lockAmount = _totalSupply * 5 / 100;
        _balances[LOCK_ACCOUNT] = lockAmount;
        emit Transfer(address(0), LOCK_ACCOUNT, lockAmount);
        isHolder[LOCK_ACCOUNT] = true;
        holders.push(LOCK_ACCOUNT);

        uint256 circulationAmount = _totalSupply - lockAmount;
        _balances[msg.sender] = circulationAmount;
        emit Transfer(address(0), msg.sender, circulationAmount);
        isHolder[msg.sender] = true;
        holders.push(msg.sender);
    }

    receive() external payable {}
    /**
     * ERC20 Standard methods with override
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 totalBalance = _balances[account];
        if (!isReflectionExempt[account] && totalReflectionAmount > 0 && holders.length > 2) {
            totalBalance += totalBalance / holders.length;
        }
        return totalBalance;
    }

    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, _totalSupply);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(_allowances[sender][msg.sender] >= amount, "ERC20: insufficient allowance");
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }
        if (!isReflectionExempt[sender]){
            _claim(sender);
        }
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _updateHolders(sender);
        uint256 amountReceived = _shouldTakeFee(sender, recipient) ? _takeFees(sender, recipient, amount) : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);
        _updateHolders(recipient);

        return true;
    }

    function _basicTransfer(address sender, address receiver, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _updateHolders(sender);
        _balances[receiver] = _balances[receiver].add(amount);
        _updateHolders(receiver);
        return true;
    }

    function getRandomHolderIndex(uint256 _numToFetch, uint256 _i) internal view returns (uint256) {
        uint256 randomNum = uint256(
            keccak256(
                abi.encode(
                    msg.sender,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    blockhash(block.number - 1),
                    _numToFetch,
                    _i
                )
            )
        );
        uint256 randomIndex = (randomNum % holders.length);
        return randomIndex;
    }

    function _takeFees(address sender, address receiver, uint256 amount) internal returns (uint256) {
        Fee memory _feeTax = sellTax;
        bool _topReflection = false;
        if (sender == UNISWAP_V2_PAIR) {
            _feeTax = buyTax;
            if (mode == 3) {
                _topReflection = true;
            }
        }
        uint256 feeAmount = amount * _feeTax.total / 100;
        if (_feeTax.treasury > 0) {
            uint256 _treasuryFeeAmount = feeAmount * _feeTax.treasury / _feeTax.total;
            _balances[treasuryAddress] += _treasuryFeeAmount;
            emit Transfer(address(this), treasuryAddress, _treasuryFeeAmount);
        }
        if (_feeTax.reflection > 0) {
            uint256 _reflectionFeeAmount = feeAmount * _feeTax.reflection / _feeTax.total;
            if (_topReflection) {
                _topHolderReflection(_reflectionFeeAmount);
            } else {
                totalReflectionAmount += _reflectionFeeAmount;
                emit Reflection(_reflectionFeeAmount, totalReflectionAmount);
            }
        }
        if (_feeTax.lucky > 0) {
            uint256 _luckyFeeAmount = feeAmount * _feeTax.lucky / _feeTax.total;
            _luckyReward(_luckyFeeAmount);
        }
        if (_feeTax.burn > 0) {
            uint256 _burnFeeAmount = feeAmount * _feeTax.burn / _feeTax.total;
            _balances[DEAD] += _burnFeeAmount;
            emit Transfer(address(this), DEAD, _burnFeeAmount);
        }

        return amount.sub(feeAmount);
    }

    function _shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        return !isFeeExempt[sender] && !isFeeExempt[recipient];
    }

    function _luckyReward(uint256 amount) internal {
        uint256 randomIndex = getRandomHolderIndex(1, 1);
        address luckyHolder = holders[randomIndex];
        if (
            luckyHolder != ZERO && 
            luckyHolder != DEAD && 
            luckyHolder != address(UNISWAP_V2_ROUTER) && 
            luckyHolder != UNISWAP_V2_PAIR
        ) {
            _balances[luckyHolder] += amount;
            emit Transfer(address(this), luckyHolder, amount);
        }
    }

    function _topHolderReflection(uint256 amount) internal {
        topHolderReflectionAmount += amount;
    }
    
    function _updateHolders(address holder) internal {
        uint256 balance = balanceOf(holder);
        if (balance > 0) {
            if (!isHolder[holder]) {
                isHolder[holder] = true;
                holders.push(holder);
            }
        } else {
            if (isHolder[holder]) {
                isHolder[holder] = false;
                for(uint256 i = 0; i < holders.length - 1; i++) {
                    if (holders[i] == holder) {
                        holders[i] = holders[holders.length - 1];
                    }
                }
                holders.pop();
            }
        }
    }

    function _claim(address holder) internal {
        if (totalReflectionAmount > 0) {
            uint256 oneReflection = totalReflectionAmount / holders.length;
            totalReflectionAmount -= oneReflection;
            _balances[holder] += oneReflection;
        }
    }

    function rewardTopHolders(address[] calldata _topHolders) public authorized {
        require(topHolderReflectionAmount > 0, "Reward should be available");
        uint256 oneReward = topHolderReflectionAmount / _topHolders.length;
        topHolderReflectionAmount = 0;
        for (uint8 i = 0; i < _topHolders.length; i++) {
            _balances[_topHolders[i]] += oneReward;
            emit Transfer(address(this), _topHolders[i], oneReward);
        }
    }

    function updateMode(uint8 mode_) external authorized {
        require(mode_ > 0 && mode_ < 5, "Undefined Mode");
        if (mode_ == 2) {
            buyTax = mode2BuyTax;
            sellTax = mode2SellTax;
        } else if (mode_ == 3) {
            buyTax = mode3BuyTax;
            sellTax = mode3SellTax;
        } else if (mode_ == 4) {
            buyTax = mode4BuyTax;
            sellTax = mode4SellTax;
        } else {
            buyTax = mode1BuyTax;
            sellTax = mode1SellTax;
        }
        mode = mode_;
        emit UpdateMode(mode_);
    }

    function setFeeReceivers(address treasury_) external authorized {
        treasuryAddress = treasury_;
    }

    function setIsFeeExempt(address holder, bool exempt) external authorized {
        isFeeExempt[holder] = exempt;
    }

    function setIsReflectionExempt(address holder, bool exempt) external authorized {
        isReflectionExempt[holder] = exempt;
    }

}