// import Link from 'next/link'

import {GetServerSideProps} from "next";

// 特に型を拡張してないので、GetServerSidePropsが使える
export const getServerSideProps: GetServerSideProps = async function () {
  return {
    props: {
      host: process.env.NEXT_HOST,
      port: process.env.PORT,
    }
  }
}


type Props = {
  host: string
  port: string
}

export default function Home({ host, port }: Props): JSX.Element {
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
