// import Link from 'next/link'

export const getServerSideProps = async function ({ req, res }) {
  return {
    props: {
      host: process.env.NEXT_HOST,
      port: process.env.PORT,
    }
  }
}


export default function Home({ host, port }) {
  return (
    <>
      <h1>Index page</h1>

      {/* クライアントでのルーティングができないので、aタグに差し替え */}
      <a href={`${host}:${port}/profile`}>Go</a>
      {/*<Link href="/profile" passHref>*/}
      {/*  <button>Go Profile</button>*/}
      {/*</Link>*/}
    </>
  )
}
