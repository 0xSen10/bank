// tokenBankUI.ts
import { createPublicClient, createWalletClient, custom, http, parseEther, getAddress } from 'viem';
import { sepolia } from 'viem/chains';
import BASE_ERC20_ABI from './BASE_ERC20_ABI.json';
import TOKEN_BANK_ABI from './TOKEN_BANK_ABI.json';

const ERC20_PERMIT_ADDRESS: `0x${string}` = '0xBdC603778397Aa19FdB8c31c8E12829928B043Ad';
const TOKEN_BANK_ADDRESS: `0x${string}` = '0xe52f2A3e97874E87B9B3fD9EBf40ff703ed2183e';

export class TokenBankUI {
  private publicClient;
  private walletClient;

  constructor(provider: any) {
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
  async depositWithApproval(amount: string): Promise<void> {
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
    } catch (error) {
      console.error('Deposit with approval failed:', error);
      throw error;
    }
  }

  // 通过签名存款（使用 ERC20 Permit）
  async depositWithSignature(amount: string): Promise<void> {
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

      // 2. 获取 domain separator (如果需要)
      // 2. 类型安全的地址处理
      // 注意：viem 会自动处理 EIP-712 域，通常不需要手动获取

      // 3. 创建 permit 签名
      const permitMessage = {
        owner: account,
        spender: TOKEN_BANK_ADDRESS,
        value: amountWei,
        nonce: nonce as bigint,
        deadline: deadline
      };

       // 4. 使用 viem 的 signTypedData 进行 EIP-712 签名
    const signature = await this.walletClient.signTypedData({
      account,
      domain: {
        name: "senERC20",
        version: "1",
        chainId: sepolia.id,
        verifyingContract: ERC20_PERMIT_ADDRESS as `0x${string}`
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

      // 5. 调用银行的 depositWithPermit 方法
      // viem 会自动处理签名的分割
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

    } catch (error) {
      console.error("Deposit with signature failed:", error);
      throw error;
    }
  }

  // 检查 TokenBank 是否支持 permit 功能
  async supportsPermit(): Promise<boolean> {
    try {
      const hasFunction = await this.publicClient.readContract({
        address: TOKEN_BANK_ADDRESS,
        abi: TOKEN_BANK_ABI,
        functionName: 'depositWithPermit'
      }).then(() => true).catch(() => false);
      
      return hasFunction;
    } catch {
      return false;
    }
  }

  // 获取代币余额
  async getTokenBalance(address: string): Promise<string> {
    const balance = await this.publicClient.readContract({
      address: ERC20_PERMIT_ADDRESS,
      abi: BASE_ERC20_ABI,
      functionName: 'balanceOf',
      args: [getAddress(address)]
    });

    // 假设代币有 18 位小数
    return (Number(balance) / 1e18).toString();
  }

  // 获取银行余额
  async getBankBalance(address: string): Promise<string> {
    const balance = await this.publicClient.readContract({
      address: TOKEN_BANK_ADDRESS,
      abi: TOKEN_BANK_ABI,
      functionName: 'getBalance',
      args: [getAddress(address)]
    });

    // 假设代币有 18 位小数
    return (Number(balance) / 1e18).toString();
  }
}