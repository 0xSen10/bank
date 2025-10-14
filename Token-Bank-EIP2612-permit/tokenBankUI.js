// tokenBankUI.js
import { 
  createPublicClient, 
  createWalletClient, 
  custom, 
  http, 
  parseEther, 
  getAddress 
} from 'viem';
import { sepolia } from 'viem/chains';

const ERC20_PERMIT_ADDRESS = '0xBdC603778397Aa19FdB8c31c8E12829928B043Ad';
const TOKEN_BANK_ADDRESS = '0xe52f2A3e97874E87B9B3fD9EBf40ff703ed2183e';

const BASE_ERC20_ABI = [
    {
        "inputs": [
            {
                "internalType": "string",
                "name": "name",
                "type": "string"
            },
            {
                "internalType": "string",
                "name": "symbol",
                "type": "string"
            }
        ],
        "stateMutability": "nonpayable",
        "type": "constructor"
    },
    {
        "inputs": [],
        "name": "ECDSAInvalidSignature",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "length",
                "type": "uint256"
            }
        ],
        "name": "ECDSAInvalidSignatureLength",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "bytes32",
                "name": "s",
                "type": "bytes32"
            }
        ],
        "name": "ECDSAInvalidSignatureS",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "spender",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "allowance",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "needed",
                "type": "uint256"
            }
        ],
        "name": "ERC20InsufficientAllowance",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "sender",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "balance",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "needed",
                "type": "uint256"
            }
        ],
        "name": "ERC20InsufficientBalance",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "approver",
                "type": "address"
            }
        ],
        "name": "ERC20InvalidApprover",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "receiver",
                "type": "address"
            }
        ],
        "name": "ERC20InvalidReceiver",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "sender",
                "type": "address"
            }
        ],
        "name": "ERC20InvalidSender",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "spender",
                "type": "address"
            }
        ],
        "name": "ERC20InvalidSpender",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "InvalidShortString",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "string",
                "name": "str",
                "type": "string"
            }
        ],
        "name": "StringTooLong",
        "type": "error"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "address",
                "name": "owner",
                "type": "address"
            },
            {
                "indexed": true,
                "internalType": "address",
                "name": "spender",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "value",
                "type": "uint256"
            }
        ],
        "name": "Approval",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [],
        "name": "EIP712DomainChanged",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "address",
                "name": "from",
                "type": "address"
            },
            {
                "indexed": true,
                "internalType": "address",
                "name": "to",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "value",
                "type": "uint256"
            }
        ],
        "name": "Transfer",
        "type": "event"
    },
    {
        "inputs": [],
        "name": "DOMAIN_SEPARATOR",
        "outputs": [
            {
                "internalType": "bytes32",
                "name": "",
                "type": "bytes32"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "owner",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "spender",
                "type": "address"
            }
        ],
        "name": "allowance",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "spender",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "value",
                "type": "uint256"
            }
        ],
        "name": "approve",
        "outputs": [
            {
                "internalType": "bool",
                "name": "",
                "type": "bool"
            }
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "account",
                "type": "address"
            }
        ],
        "name": "balanceOf",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "decimals",
        "outputs": [
            {
                "internalType": "uint8",
                "name": "",
                "type": "uint8"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "eip712Domain",
        "outputs": [
            {
                "internalType": "bytes1",
                "name": "fields",
                "type": "bytes1"
            },
            {
                "internalType": "string",
                "name": "name",
                "type": "string"
            },
            {
                "internalType": "string",
                "name": "version",
                "type": "string"
            },
            {
                "internalType": "uint256",
                "name": "chainId",
                "type": "uint256"
            },
            {
                "internalType": "address",
                "name": "verifyingContract",
                "type": "address"
            },
            {
                "internalType": "bytes32",
                "name": "salt",
                "type": "bytes32"
            },
            {
                "internalType": "uint256[]",
                "name": "extensions",
                "type": "uint256[]"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            }
        ],
        "name": "mint",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "name",
        "outputs": [
            {
                "internalType": "string",
                "name": "",
                "type": "string"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "owner",
                "type": "address"
            }
        ],
        "name": "nonces",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "owner",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "spender",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "value",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "deadline",
                "type": "uint256"
            },
            {
                "internalType": "uint8",
                "name": "v",
                "type": "uint8"
            },
            {
                "internalType": "bytes32",
                "name": "r",
                "type": "bytes32"
            },
            {
                "internalType": "bytes32",
                "name": "s",
                "type": "bytes32"
            }
        ],
        "name": "permit",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "symbol",
        "outputs": [
            {
                "internalType": "string",
                "name": "",
                "type": "string"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "totalSupply",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "to",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "value",
                "type": "uint256"
            }
        ],
        "name": "transfer",
        "outputs": [
            {
                "internalType": "bool",
                "name": "",
                "type": "bool"
            }
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "from",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "to",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "value",
                "type": "uint256"
            }
        ],
        "name": "transferFrom",
        "outputs": [
            {
                "internalType": "bool",
                "name": "",
                "type": "bool"
            }
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

const TOKEN_BANK_ABI = [
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "tokenAddress",
                "type": "address"
            }
        ],
        "stateMutability": "nonpayable",
        "type": "constructor"
    },
     {
    "constant": true,
    "inputs": [{"name": "user", "type": "address"}],
    "name": "balanceOf",  // 可能是这个
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "name": "balances",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            }
        ],
        "name": "deposit",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "deadline",
                "type": "uint256"
            },
            {
                "internalType": "uint8",
                "name": "v",
                "type": "uint8"
            },
            {
                "internalType": "bytes32",
                "name": "r",
                "type": "bytes32"
            },
            {
                "internalType": "bytes32",
                "name": "s",
                "type": "bytes32"
            }
        ],
        "name": "permitDeposit",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "maxAmount",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "deadline",
                "type": "uint256"
            },
            {
                "internalType": "uint8",
                "name": "v",
                "type": "uint8"
            },
            {
                "internalType": "bytes32",
                "name": "r",
                "type": "bytes32"
            },
            {
                "internalType": "bytes32",
                "name": "s",
                "type": "bytes32"
            }
        ],
        "name": "permitDepositWithMax",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "token",
        "outputs": [
            {
                "internalType": "contract ERC20Permit",
                "name": "",
                "type": "address"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            }
        ],
        "name": "withdraw",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

export class TokenBankUI {
    constructor(provider) {
        this.publicClient = createPublicClient({
            chain: sepolia,
            transport: http()
        });
        this.walletClient = createWalletClient({
            chain: sepolia,
            transport: custom(provider)
        });
    }

    // 传统的授权+存款方式
    async depositWithApproval(amount) {
        const [account] = await this.walletClient.getAddresses();
        const amountWei = parseEther(amount);
        try {
            // 先授权
            const approveHash = await this.walletClient.writeContract({
                address: ERC20_PERMIT_ADDRESS,
                abi: BASE_ERC20_ABI,
                functionName: 'approve',
                args: [TOKEN_BANK_ADDRESS, amountWei],
                account
            });
            await this.publicClient.waitForTransactionReceipt({ hash: approveHash });

            // 再存款
            const depositHash = await this.walletClient.writeContract({
                address: TOKEN_BANK_ADDRESS,
                abi: TOKEN_BANK_ABI,
                functionName: 'deposit',
                args: [amountWei],
                account
            });
            await this.publicClient.waitForTransactionReceipt({ hash: depositHash });
        }
        catch (error) {
            console.error('Deposit with approval failed:', error);
            throw error;
        }
    }

    // 通过签名存款（使用 ERC20 Permit）
    async depositWithSignature(amount) {
        const [account] = await this.walletClient.getAddresses();
        const amountWei = parseEther(amount);
        const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1小时后过期
        try {
            // 1. 获取当前 nonce
            const nonce = await this.publicClient.readContract({
                address: ERC20_PERMIT_ADDRESS,
                abi: BASE_ERC20_ABI,
                functionName: 'nonces',
                args: [account]
            });

            // 2. 创建 permit 签名
            const permitMessage = {
                owner: account,
                spender: TOKEN_BANK_ADDRESS,
                value: amountWei,
                nonce: nonce,
                deadline: deadline
            };

            // 3. 使用 viem 的 signTypedData 进行 EIP-712 签名
            const signature = await this.walletClient.signTypedData({
                account,
                domain: {
                    name: "senERC20",
                    version: "1",
                    chainId: sepolia.id,
                    verifyingContract: ERC20_PERMIT_ADDRESS
                },
                types: {
                    Permit: [
                        { name: "owner", type: "address" },
                        { name: "spender", type: "address" },
                        { name: "value", type: "uint256" },
                        { name: "nonce", type: "uint256" },
                        { name: "deadline", type: "uint256" }
                    ]
                },
                primaryType: 'Permit',
                message: permitMessage
            });

            // 4. 调用银行的 depositWithPermit 方法
            const txHash = await this.walletClient.writeContract({
                address: TOKEN_BANK_ADDRESS,
                abi: TOKEN_BANK_ABI,
                functionName: 'depositWithPermit',
                args: [
                    amountWei,
                    deadline,
                    signature
                ],
                account
            });
            await this.publicClient.waitForTransactionReceipt({ hash: txHash });
            console.log("Deposit with signature successful!");
        }
        catch (error) {
            console.error("Deposit with signature failed:", error);
            throw error;
        }
    }

    // 添加取款方法
    async withdraw(amount) {
        const [account] = await this.walletClient.getAddresses();
        const amountWei = parseEther(amount);
        try {
            const withdrawHash = await this.walletClient.writeContract({
                address: TOKEN_BANK_ADDRESS,
                abi: TOKEN_BANK_ABI,
                functionName: 'withdraw',
                args: [amountWei],
                account
            });
            await this.publicClient.waitForTransactionReceipt({ hash: withdrawHash });
            console.log("Withdrawal successful!");
        }
        catch (error) {
            console.error("Withdrawal failed:", error);
            throw error;
        }
    }

    // 检查 TokenBank 是否支持 permit 功能
    async supportsPermit() {
        try {
            const hasFunction = await this.publicClient.readContract({
                address: TOKEN_BANK_ADDRESS,
                abi: TOKEN_BANK_ABI,
                functionName: 'depositWithPermit'
            }).then(() => true).catch(() => false);
            return hasFunction;
        }
        catch {
            return false;
        }
    }

    // 获取代币余额
    async getTokenBalance(address) {
        const balance = await this.publicClient.readContract({
            address: ERC20_PERMIT_ADDRESS,
            abi: BASE_ERC20_ABI,
            functionName: 'balanceOf',
            args: [getAddress(address)]
        });
        return (Number(balance) / 1e18).toString();
    }

    // 获取银行余额
    async getBankBalance(address) {
        const balance = await this.publicClient.readContract({
            address: TOKEN_BANK_ADDRESS,
            abi: TOKEN_BANK_ABI,
            functionName: 'getBalance',
            args: [getAddress(address)]
        });
        return (Number(balance) / 1e18).toString();
    }
}