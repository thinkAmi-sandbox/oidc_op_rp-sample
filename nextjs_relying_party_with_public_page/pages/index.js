import Link from 'next/link'

export default function Home() {
  return (
    <>
      <h1>Index page</h1>
      <Link href="/profile" passHref>
        <button>Go Profile</button>
      </Link>
    </>
  )
}
