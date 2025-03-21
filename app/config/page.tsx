import { ConfigForm } from "@/components/config-form"
import { LocalNetworkInfo } from "@/components/local-network-info"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

export default function ConfigPage() {
  return (
    <main className="min-h-screen bg-black text-white">
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold mb-8">配置</h1>

        <Tabs defaultValue="connection" className="w-full max-w-md mx-auto">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="connection">连接设置</TabsTrigger>
            <TabsTrigger value="help">帮助信息</TabsTrigger>
          </TabsList>
          <TabsContent value="connection">
            <ConfigForm />
          </TabsContent>
          <TabsContent value="help">
            <LocalNetworkInfo />
          </TabsContent>
        </Tabs>
      </div>
    </main>
  )
}

